import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turnos_juegos/core/audio/sound_preview_service.dart';

/// Device: `flutter test integration_test/sound_preview_integration_test.dart -d <id>`
/// Lifecycle/state only — not audible perception.
class _FakePlayer implements SoundPreviewPlayer {
  final _states = StreamController<PlayerState>.broadcast();
  final calls = <String>[];
  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;
  @override
  Future<void> stop() async {
    calls.add('stop');
    _states.add(PlayerState.stopped);
  }

  @override
  Future<void> playAsset(
    String assetSourcePath, {
    required double volume,
    required PlayerMode mode,
    AudioContext? ctx,
    ReleaseMode releaseMode = ReleaseMode.release,
  }) async {
    calls.add('play:$assetSourcePath');
    _states.add(PlayerState.playing);
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _states.close();
  }
}

String _failureReason(SoundPreviewResult result) {
  if (result is SoundPreviewFailure) {
    return 'SoundPreviewFailure(${result.error}) soundId=${result.soundId}';
  }
  return 'unexpected result: $result';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fake player: play/stop/dispose orchestration', (tester) async {
    final player = _FakePlayer();
    final service =
        SoundPreviewService(player: player, audioContext: AudioContext());
    expect(await service.preview('sound_1'), isA<SoundPreviewStarted>());
    await service.stop();
    await service.dispose();
    expect(player.calls, [
      'stop',
      'play:sounds/click_1.wav',
      'stop',
      'stop',
      'dispose',
    ]);
  });

  testWidgets('real AudioplayersPreviewPlayer: start/stop/dispose',
      (tester) async {
    final service = SoundPreviewService(
      player: AudioplayersPreviewPlayer(),
      playingTimeout: const Duration(seconds: 5),
    );
    addTearDown(service.dispose);
    final result = await service.preview('sound_1').timeout(
          const Duration(seconds: 8),
          onTimeout: () => const SoundPreviewFailure(
            'sound_1',
            SoundPreviewError.playTimeout,
          ),
        );
    expect(
      result,
      isA<SoundPreviewStarted>(),
      reason: _failureReason(result),
    );
    expect((result as SoundPreviewStarted).soundId, 'sound_1');
    await service.stop().timeout(const Duration(seconds: 3));
    await service.dispose().timeout(const Duration(seconds: 3));
  });
}
