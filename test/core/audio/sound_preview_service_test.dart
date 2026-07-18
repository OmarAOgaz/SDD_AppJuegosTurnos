import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/audio/sound_preview_service.dart';
import 'package:turnos_juegos/core/catalogs/sound_catalog.dart';

class _Fake implements SoundPreviewPlayer {
  final _states = StreamController<PlayerState>.broadcast();
  final calls = <String>[];
  bool failPlay = false;
  bool hangPlay = false;
  bool emitPlaying = true;
  Duration playDelay = Duration.zero;
  int plays = 0;
  int disposals = 0;
  double? volume;
  PlayerMode? mode;

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
    plays++;
    this.volume = volume;
    this.mode = mode;
    calls.add('play:$assetSourcePath');
    if (failPlay) throw Exception('fail');
    if (hangPlay) await Completer<void>().future;
    if (playDelay > Duration.zero) await Future<void>.delayed(playDelay);
    if (emitPlaying) _states.add(PlayerState.playing);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await _states.close();
  }
}

Future<String> _sha256(File file) async {
  final r = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    "(Get-FileHash -Algorithm SHA256 -LiteralPath '${file.absolute.path}').Hash.ToLower()",
  ]);
  expect(r.exitCode, 0, reason: r.stderr.toString());
  return r.stdout.toString().trim().toLowerCase();
}

void main() {
  SoundPreviewService svc(_Fake f) =>
      SoundPreviewService(player: f, audioContext: AudioContext());

  test('preview core: path, stop/play, volume, failure, timeout, dispose',
      () async {
    expect(
      SoundPreviewService.assetSourcePath('assets/sounds/click_1.wav'),
      'sounds/click_1.wav',
    );
    final ok = _Fake();
    final started = await svc(ok).preview('sound_1');
    expect(started, isA<SoundPreviewStarted>());
    expect(ok.calls, ['stop', 'play:sounds/click_1.wav']);
    expect(ok.volume, 0.75);
    expect(ok.mode, PlayerMode.lowLatency);

    expect(
      ((await svc(_Fake()..failPlay = true).preview('sound_2'))
              as SoundPreviewFailure)
          .error,
      SoundPreviewError.loadFailed,
    );

    // Successful playAsset without a playing stream event still counts as started.
    final noEvent = await svc(_Fake()..emitPlaying = false).preview('sound_3');
    expect(noEvent, isA<SoundPreviewStarted>());
    expect((noEvent as SoundPreviewStarted).soundId, 'sound_3');

    final timed = await SoundPreviewService(
      player: _Fake()..hangPlay = true,
      audioContext: AudioContext(),
      playingTimeout: const Duration(milliseconds: 40),
    ).preview('sound_4');
    expect(
      (timed as SoundPreviewFailure).error,
      SoundPreviewError.playTimeout,
    );

    final d = _Fake();
    final s = svc(d);
    await s.dispose();
    expect(
      ((await s.preview('sound_1')) as SoundPreviewFailure).error,
      SoundPreviewError.disposed,
    );
    expect(d.disposals, 1);
  });

  test('rapid cancel and sequential replacement', () async {
    final rapid = _Fake()..playDelay = const Duration(milliseconds: 30);
    final s = svc(rapid);
    final both =
        await Future.wait([s.preview('sound_1'), s.preview('sound_5')]);
    expect((both[0] as SoundPreviewFailure).error, SoundPreviewError.cancelled);
    expect((both[1] as SoundPreviewStarted).soundId, 'sound_5');
    expect(rapid.plays, 1);

    final f = _Fake();
    final seq = svc(f);
    await seq.preview('sound_1');
    await seq.preview('sound_5');
    expect(f.calls, [
      'stop',
      'play:sounds/click_1.wav',
      'stop',
      'play:sounds/switch_1.wav',
    ]);
  });

  test('cancel during play does not complete as started', () async {
    final f = _Fake()..playDelay = const Duration(milliseconds: 80);
    final s = svc(f);
    final first = s.preview('sound_1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await s.stop();
    expect(
      ((await first) as SoundPreviewFailure).error,
      SoundPreviewError.cancelled,
    );
  });

  test('catalog assets: labels, WAV header, peak, checksums', () async {
    expect(SoundCatalog.all, hasLength(8));
    expect(SoundCatalog.allIds().toSet(), hasLength(8));
    expect(SoundCatalog.all.map((e) => e.displayName).toSet(), hasLength(8));
    expect(SoundCatalog.byId('sound_1')?.displayName, 'Clic claro');
    final expected = <String, String>{};
    final shaLine = File('assets/sounds/ATTRIBUTION.md')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('SHA-256:'));
    for (final m
        in RegExp(r'([0-9a-f]{64})\s+(\S+\.wav)').allMatches(shaLine)) {
      expected[m.group(2)!] = m.group(1)!;
    }
    final hashes = <String>{};
    for (final e in SoundCatalog.all) {
      final name = e.assetPath.split('/').last;
      final bytes = File(e.assetPath).readAsBytesSync();
      final v = ByteData.sublistView(bytes);
      expect(utf8.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(v.getUint16(22, Endian.little), 1);
      expect(v.getUint32(24, Endian.little), 44100);
      expect(v.getUint16(34, Endian.little), 16);
      var peak = 0;
      for (var i = 44; i + 1 < bytes.length; i += 2) {
        final s = v.getInt16(i, Endian.little).abs();
        if (s > peak) peak = s;
      }
      expect(peak > 1000 && peak <= 29204, isTrue);
      hashes.add(await _sha256(File(e.assetPath)));
      expect(hashes.last, expected[name]);
    }
    expect(hashes, hasLength(8));
  });
}
