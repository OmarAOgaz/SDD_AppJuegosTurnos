import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/pause_gated_lifecycle.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';

void main() {
  const liveAd = DiscoveredRoom(
    roomId: 'room-1',
    displayName: 'Sala',
    hostIp: '10.0.0.2',
    port: 4242,
  );

  group('shouldCancelRecoveryAfterPauseCoalesce', () {
    test('brief inactive (already resumed) MUST NOT cancel recovery', () {
      expect(
        shouldCancelRecoveryAfterPauseCoalesce(stillNonForeground: false),
        isFalse,
      );
    });

    test('sustained non-foreground MUST cancel recovery timer', () {
      expect(
        shouldCancelRecoveryAfterPauseCoalesce(stillNonForeground: true),
        isTrue,
      );
    });
  });

  group('planClientResumeAfterSustainedPause', () {
    test('resume finds live host → reconnect (no succession)', () {
      expect(
        planClientResumeAfterSustainedPause(liveAd: liveAd),
        PauseGatedClientResumePlan.reconnectToLiveHost,
      );
    });

    test('resume after true host death → restart recovery grace', () {
      expect(
        planClientResumeAfterSustainedPause(liveAd: null),
        PauseGatedClientResumePlan.restartRecoveryGrace,
      );
    });
  });

  group('shouldYieldHostingOnResume', () {
    test('demote when acting host sees live ads and is not original', () {
      expect(
        shouldYieldHostingOnResume(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          turnSequence: const ['p1', 'p2', 'p3'],
          hasPeerAd: true,
          peerHostPlayerId: null,
        ),
        isTrue,
      );
    });

    test('original host keeps authority when peer ads appear', () {
      expect(
        shouldYieldHostingOnResume(
          localPlayerId: 'p1',
          originalHostPlayerId: 'p1',
          turnSequence: const ['p1', 'p2', 'p3'],
          hasPeerAd: true,
          peerHostPlayerId: null,
        ),
        isFalse,
      );
    });

    test('dual acting-host tie-break uses peer id when known', () {
      expect(
        shouldYieldHostingOnResume(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          turnSequence: const ['p1', 'p2', 'p3'],
          hasPeerAd: true,
          peerHostPlayerId: 'p2',
        ),
        isTrue,
      );
      expect(
        shouldYieldHostingOnResume(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          turnSequence: const ['p1', 'p2', 'p3'],
          hasPeerAd: true,
          peerHostPlayerId: 'p3',
        ),
        isFalse,
      );
    });

    test('no peer ad → do not yield', () {
      expect(
        shouldYieldHostingOnResume(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          turnSequence: const ['p1', 'p2'],
          hasPeerAd: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldSuppressSuccessionAfterDemote', () {
    test('post-demote TCP fail with live ads → suppress succession', () {
      expect(
        shouldSuppressSuccessionAfterDemote(
          suppressArmed: true,
          liveAd: liveAd,
        ),
        isTrue,
      );
    });

    test('post-demote without live ads → allow succession path', () {
      expect(
        shouldSuppressSuccessionAfterDemote(
          suppressArmed: true,
          liveAd: null,
        ),
        isFalse,
      );
    });

    test('suppress flag off → never suppress', () {
      expect(
        shouldSuppressSuccessionAfterDemote(
          suppressArmed: false,
          liveAd: liveAd,
        ),
        isFalse,
      );
    });
  });
}
