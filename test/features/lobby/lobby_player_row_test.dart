import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/audio/sound_preview_service.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/features/lobby/widgets/color_picker_sheet.dart';
import 'package:turnos_juegos/features/lobby/widgets/lobby_player_row.dart';
import 'package:turnos_juegos/features/lobby/widgets/sound_picker_sheet.dart';

Player _player({String displayName = 'Ana', bool connected = true}) {
  return Player(
    playerId: 'p1',
    displayName: displayName,
    colorId: 'color_1',
    soundId: 'sound_1',
    deviceId: 'device-1',
    slotNumber: 1,
    connected: connected,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Player player, {
  required bool isSelf,
  required bool showHostAdminSlot,
  ValueChanged<String>? onNameChanged,
  ValueChanged<String>? onColorChanged,
  ValueChanged<String>? onSoundChanged,
  Set<String> takenColorIds = const {},
  Set<String> takenSoundIds = const {},
  SoundPreviewService? previewService,
}) {
  final row = LobbyPlayerRow(
    player: player,
    isSelf: isSelf,
    showHostAdminSlot: showHostAdminSlot,
    reorderIndex: 0,
    reorderCount: 2,
    onMoveUp: () {},
    onMoveDown: () {},
    onNameChanged: onNameChanged,
    onColorChanged: onColorChanged,
    onSoundChanged: onSoundChanged,
    takenColorIds: takenColorIds,
    takenSoundIds: takenSoundIds,
    previewService: previewService,
  );
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: showHostAdminSlot
            ? ReorderableListView(
                onReorderItem: (_, __) {},
                buildDefaultDragHandles: false,
                children: [KeyedSubtree(key: const ValueKey('r'), child: row)],
              )
            : row,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'host and client share row structure; admin slot is host-only',
    (tester) async {
      final player = _player();

      await _pump(tester, player, isSelf: false, showHostAdminSlot: true);
      expect(find.text('Jugador 1'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.byKey(const Key('lobby-admin-slot')), findsOneWidget);
      expect(find.byKey(const Key('lobby-reorder-up-0')), findsOneWidget);
      expect(find.byKey(const Key('lobby-reorder-drag')), findsOneWidget);

      await _pump(tester, player, isSelf: false, showHostAdminSlot: false);
      expect(find.byKey(const Key('lobby-admin-slot')), findsNothing);
      expect(find.byKey(const Key('lobby-reorder-up-0')), findsNothing);
    },
  );

  testWidgets('own connected row is editable', (tester) async {
    var changed = '';
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      onNameChanged: (value) => changed = value,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ana2');
    expect(changed, 'Ana2');
  });

  testWidgets('another player row is read-only', (tester) async {
    await _pump(
      tester,
      _player(),
      isSelf: false,
      showHostAdminSlot: false,
      onNameChanged: (_) => fail('non-self row must not be editable'),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('a disconnected self row disables editing', (tester) async {
    final preview =
        SoundPreviewService(player: _Noop(), audioContext: AudioContext());
    addTearDown(preview.dispose);
    await _pump(
      tester,
      _player(connected: false),
      isSelf: true,
      showHostAdminSlot: false,
      onNameChanged: (_) => fail('disconnected row must not be editable'),
      onColorChanged: (_) => fail('disconnected row must not open color'),
      onSoundChanged: (_) => fail('disconnected row must not open sound'),
      previewService: preview,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('lobby-color-button')), findsNothing);
    expect(find.byKey(const Key('lobby-sound-button')), findsNothing);
    expect(find.text('Desconectado'), findsOneWidget);
  });

  testWidgets('Color and Sound controls only on own connected row',
      (tester) async {
    final color = find.byKey(const Key('lobby-color-button'));
    final sound = find.byKey(const Key('lobby-sound-button'));
    final preview =
        SoundPreviewService(player: _Noop(), audioContext: AudioContext());
    addTearDown(preview.dispose);
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      onColorChanged: (_) {},
      onSoundChanged: (_) {},
      previewService: preview,
    );
    expect(color, findsOneWidget);
    expect(sound, findsOneWidget);
    await tester.tap(sound);
    await tester.pumpAndSettle();
    expect(find.byType(SoundPickerSheet), findsOneWidget);

    await _pump(tester, _player(), isSelf: false, showHostAdminSlot: false);
    expect(color, findsNothing);
    expect(sound, findsNothing);

    await _pump(
      tester,
      _player(connected: false),
      isSelf: true,
      showHostAdminSlot: false,
      onColorChanged: (_) {},
      onSoundChanged: (_) {},
      previewService: preview,
    );
    expect(color, findsNothing);
    expect(sound, findsNothing);
  });

  testWidgets('Color opens sheet and reports selection', (tester) async {
    var newColorId = '';
    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: false,
      takenColorIds: const {'color_2'},
      onColorChanged: (value) => newColorId = value,
    );
    await tester.tap(find.byKey(const Key('lobby-color-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('color-option-color_3')));
    await tester.pumpAndSettle();
    expect(newColorId, 'color_3');
    expect(find.byType(ColorPickerSheet), findsNothing);
  });

  testWidgets('host self+admin fits phone width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterErrorDetails? overflow;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflow = details;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await _pump(
      tester,
      _player(),
      isSelf: true,
      showHostAdminSlot: true,
      onNameChanged: (_) {},
      onColorChanged: (_) {},
      onSoundChanged: (_) {},
      previewService: SoundPreviewService(player: _Noop()),
    );
    await tester.pumpAndSettle();
    expect(overflow, isNull);
    expect(find.byKey(const Key('lobby-color-button')), findsOneWidget);
    expect(find.byKey(const Key('lobby-reorder-drag')), findsOneWidget);
  });
}

class _Noop implements SoundPreviewPlayer {
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
