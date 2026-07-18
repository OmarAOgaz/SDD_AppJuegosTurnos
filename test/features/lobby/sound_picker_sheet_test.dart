import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/audio/sound_preview_service.dart';
import 'package:turnos_juegos/core/catalogs/sound_catalog.dart';
import 'package:turnos_juegos/core/domain/eligible_picker.dart';
import 'package:turnos_juegos/features/lobby/widgets/sound_picker_sheet.dart';

class _S extends SoundPreviewService {
  _S(this.h) : super(player: _P(), audioContext: AudioContext());
  final Future<SoundPreviewResult> Function(String id) h;
  @override
  Future<SoundPreviewResult> preview(String id) => h(id);
}

class _P implements SoundPreviewPlayer {
  final _s = StreamController<PlayerState>.broadcast();
  @override
  Stream<PlayerState> get onPlayerStateChanged => _s.stream;
  @override
  Future<void> stop() async {}
  @override
  Future<void> playAsset(
    String p, {
    required double volume,
    required PlayerMode mode,
    AudioContext? ctx,
    ReleaseMode releaseMode = ReleaseMode.release,
  }) async {}
  @override
  Future<void> dispose() async => _s.close();
}

void main() {
  testWidgets('visible/taken/commit-after-start/error', (tester) async {
    final handle = tester.ensureSemantics();
    final commits = <String>[];
    final calls = <String>[];
    final svc = _S((id) async {
      calls.add(id);
      if (id == 'sound_4') {
        return SoundPreviewFailure(id, SoundPreviewError.loadFailed);
      }
      return SoundPreviewStarted(id);
    });
    Future<void> sheet({Set<String> taken = const {}}) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SoundPickerSheet(
                key: UniqueKey(),
                options: soundPickerOptions(
                  takenSoundIds: taken,
                  ownSoundId: 'sound_1',
                ),
                currentSoundId: 'sound_1',
                previewService: svc,
                onCommitted: commits.add,
              ),
            ),
          ),
        );

    await sheet(taken: const {'sound_2'});
    for (final s in SoundCatalog.all) {
      expect(find.text(s.displayName), findsOneWidget);
      expect(
        tester.getSize(find.byKey(Key('sound-option-${s.id}'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.bySemanticsLabel('Clic grave, no disponible'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound-option-sound_2')));
    await tester.pump();
    expect(commits, isEmpty);
    await tester.tap(find.byKey(const Key('sound-option-sound_5')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(commits, ['sound_5']);

    commits.clear();
    await sheet();
    await tester.tap(find.byKey(const Key('sound-option-sound_4')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(commits, isEmpty);
    expect(find.byKey(const Key('sound-preview-error')), findsOneWidget);
    await svc.dispose();
    handle.dispose();
  });

  testWidgets('pending locks taps; error then retry commits', (tester) async {
    final handle = tester.ensureSemantics();
    final commits = <String>[];
    final calls = <String>[];
    final gate = Completer<SoundPreviewResult>();
    var sound3Attempts = 0;
    final svc = _S((id) async {
      calls.add(id);
      if (id == 'sound_3') {
        sound3Attempts++;
        if (sound3Attempts == 1) {
          return gate.future;
        }
        return SoundPreviewStarted(id);
      }
      return SoundPreviewStarted(id);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundPickerSheet(
            options: soundPickerOptions(
              takenSoundIds: const {},
              ownSoundId: 'sound_1',
            ),
            currentSoundId: 'sound_1',
            previewService: svc,
            onCommitted: commits.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sound-option-sound_3')));
    await tester.pump();
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

    // While pending, free tiles are visually/tactilely/semantically disabled.
    final freeTile = tester.getSemantics(
      find.byKey(const Key('sound-option-sound_5')),
    );
    expect(freeTile.hasFlag(SemanticsFlag.isEnabled), isFalse);
    final pendingTile = tester.getSemantics(
      find.byKey(const Key('sound-option-sound_3')),
    );
    expect(pendingTile.hasFlag(SemanticsFlag.isEnabled), isFalse);

    // Rapid second activation must not start another preview.
    await tester.tap(find.byKey(const Key('sound-option-sound_5')));
    await tester.pump();
    expect(calls, ['sound_3']);
    expect(commits, isEmpty);

    gate.complete(
      SoundPreviewFailure('sound_3', SoundPreviewError.loadFailed),
    );
    await tester.pump();
    expect(commits, isEmpty);
    expect(find.byKey(const Key('sound-preview-error')), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top), findsNothing);

    // After failure, interaction unlocks and retry can commit.
    final unlocked = tester.getSemantics(
      find.byKey(const Key('sound-option-sound_5')),
    );
    expect(unlocked.hasFlag(SemanticsFlag.isEnabled), isTrue);

    await tester.tap(find.byKey(const Key('sound-option-sound_3')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(commits, ['sound_3']);
    expect(calls, ['sound_3', 'sound_3']);

    await svc.dispose();
    handle.dispose();
  });
}
