import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../catalogs/sound_catalog.dart';

sealed class SoundPreviewResult {
  const SoundPreviewResult(this.soundId);
  final String soundId;
}

final class SoundPreviewStarted extends SoundPreviewResult {
  const SoundPreviewStarted(super.soundId);
}

final class SoundPreviewFailure extends SoundPreviewResult {
  const SoundPreviewFailure(super.soundId, this.error);
  final SoundPreviewError error;
}

enum SoundPreviewError {
  unknownSound,
  loadFailed,
  playTimeout,
  cancelled,
  disposed
}

abstract class SoundPreviewPlayer {
  Stream<PlayerState> get onPlayerStateChanged;
  Future<void> stop();
  Future<void> playAsset(
    String assetSourcePath, {
    required double volume,
    required PlayerMode mode,
    AudioContext? ctx,
    ReleaseMode releaseMode,
  });
  Future<void> dispose();
}

class AudioplayersPreviewPlayer implements SoundPreviewPlayer {
  AudioplayersPreviewPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();
  final AudioPlayer _player;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> playAsset(
    String assetSourcePath, {
    required double volume,
    required PlayerMode mode,
    AudioContext? ctx,
    ReleaseMode releaseMode = ReleaseMode.release,
  }) async {
    await _player.setReleaseMode(releaseMode);
    await _player.play(
      AssetSource(assetSourcePath),
      volume: volume,
      mode: mode,
      ctx: ctx,
    );
  }
}

/// One player: stop → play; successful [playAsset] means started (plugin contract).
/// Newer previews cancel older ones. Do not require a `playing` stream event —
/// short lowLatency clips may finish before that event is observed.
///
/// Default [audioContext] is duck-then-resume short SFX (lobby + turn-start share
/// this policy). Built as a custom [AudioContext] because [AudioContextConfig]
/// asserts against combining respectSilence with duckOthers.
class SoundPreviewService {
  SoundPreviewService({
    SoundPreviewPlayer? player,
    this.volume = defaultVolume,
    this.playingTimeout = const Duration(milliseconds: 1500),
    AudioContext? audioContext,
  })  : _player = player ?? AudioplayersPreviewPlayer(),
        _ctx = audioContext ?? defaultAudioContext();

  /// Shared short-SFX policy: Android transient duck + sonification usage;
  /// iOS ambient honors the Silent switch (no duckOthers — Config assert).
  static AudioContext defaultAudioContext() {
    return AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {},
      ),
    );
  }

  static const double defaultVolume = 0.75;
  final SoundPreviewPlayer _player;
  final double volume;
  final Duration playingTimeout;
  final AudioContext _ctx;

  /// Context passed to [SoundPreviewPlayer.playAsset] (inject or [defaultAudioContext]).
  AudioContext get audioContext => _ctx;
  int _gen = 0;
  bool _disposed = false;
  Future<void> _chain = Future<void>.value();
  Completer<SoundPreviewResult>? _active;
  String? _activeId;

  static String assetSourcePath(String path) =>
      path.startsWith('assets/') ? path.substring(7) : path;

  /// Non-catalog SFX (blocked return error). Does not add a SoundCatalog entry.
  static const blockedReturnErrorAssetPath = 'assets/sounds/error_1.wav';

  Future<SoundPreviewResult> preview(String soundId) async {
    if (_disposed) {
      return SoundPreviewFailure(soundId, SoundPreviewError.disposed);
    }
    final entry = SoundCatalog.byId(soundId);
    if (entry == null) {
      return SoundPreviewFailure(soundId, SoundPreviewError.unknownSound);
    }
    return _play(resultId: soundId, assetPath: entry.assetPath);
  }

  /// Plays [assetPath] directly, bypassing [SoundCatalog] (must stay 8 entries).
  Future<SoundPreviewResult> playEffect(String assetPath) {
    return _play(resultId: assetPath, assetPath: assetPath);
  }

  Future<SoundPreviewResult> _play({
    required String resultId,
    required String assetPath,
  }) async {
    if (_disposed) {
      return SoundPreviewFailure(resultId, SoundPreviewError.disposed);
    }
    final gen = ++_gen;
    _cancel(SoundPreviewError.cancelled);
    final active = Completer<SoundPreviewResult>();
    _active = active;
    _activeId = resultId;
    await _enqueue(() async {
      if (_disposed || gen != _gen) return;
      await _player.stop();
      if (_disposed || gen != _gen) return;
      try {
        await _player
            .playAsset(
              assetSourcePath(assetPath),
              volume: volume,
              mode: PlayerMode.lowLatency,
              ctx: _ctx,
              releaseMode: ReleaseMode.release,
            )
            .timeout(playingTimeout);
        if (!active.isCompleted && gen == _gen && !_disposed) {
          // audioplayers 6.8.1: successful play() already set state=playing.
          active.complete(SoundPreviewStarted(resultId));
        }
      } on TimeoutException {
        if (!active.isCompleted && gen == _gen) {
          active.complete(
            SoundPreviewFailure(resultId, SoundPreviewError.playTimeout),
          );
        }
      } on Object {
        if (!active.isCompleted && gen == _gen) {
          active.complete(
            SoundPreviewFailure(resultId, SoundPreviewError.loadFailed),
          );
        }
      }
    });
    if (_disposed || gen != _gen) {
      return SoundPreviewFailure(
        resultId,
        _disposed ? SoundPreviewError.disposed : SoundPreviewError.cancelled,
      );
    }
    try {
      return await active.future;
    } finally {
      if (identical(_active, active)) {
        _active = null;
        _activeId = null;
      }
    }
  }

  void _cancel(SoundPreviewError error) {
    final pending = _active;
    if (pending != null && !pending.isCompleted) {
      pending.complete(SoundPreviewFailure(_activeId ?? '', error));
    }
    _active = null;
    _activeId = null;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final gate = Completer<void>();
    final prev = _chain;
    _chain = gate.future;
    return prev.catchError((_) {}).then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  Future<void> stop() async {
    _gen++;
    _cancel(SoundPreviewError.cancelled);
    if (!_disposed) await _player.stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    _cancel(SoundPreviewError.disposed);
    await _player.stop();
    await _player.dispose();
  }
}
