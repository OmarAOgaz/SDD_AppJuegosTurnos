import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/host_heal_compare.dart';
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

  group('parseHostPlatformToken / parseHostCurrentRound', () {
    test('platform tokens and missing → other', () {
      expect(parseHostPlatformToken('android'), HostPlatformToken.android);
      expect(parseHostPlatformToken('ios'), HostPlatformToken.ios);
      expect(parseHostPlatformToken('other'), HostPlatformToken.other);
      expect(parseHostPlatformToken(null), HostPlatformToken.other);
      expect(parseHostPlatformToken(''), HostPlatformToken.other);
      expect(parseHostPlatformToken('ANDROID'), HostPlatformToken.android);
    });

    test('currentRound missing/bad → 0', () {
      expect(parseHostCurrentRound(null), 0);
      expect(parseHostCurrentRound(''), 0);
      expect(parseHostCurrentRound('x'), 0);
      expect(parseHostCurrentRound('-1'), 0);
      expect(parseHostCurrentRound('3'), 3);
      expect(parseHostCurrentRound(2), 2);
    });
  });

  group('shouldYieldDualHostHeal / shouldYieldHostingOnResume', () {
    test('no peer ad → do not yield', () {
      expect(
        shouldYieldHostingOnResume(
          hasPeerAd: false,
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'android',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.2:4242',
          peerPlatform: 'ios',
          peerCurrentRound: 9,
          peerEndpoint: '10.0.0.3:4242',
        ),
        isFalse,
      );
    });

    test('original host keeps when peer ads appear', () {
      expect(
        shouldYieldHostingOnResume(
          hasPeerAd: true,
          localPlayerId: 'p1',
          originalHostPlayerId: 'p1',
          localPlatform: 'ios',
          localCurrentRound: 0,
          localEndpoint: '10.0.0.1:1',
          peerPlatform: 'android',
          peerCurrentRound: 99,
          peerEndpoint: '10.0.0.9:9999',
        ),
        isFalse,
      );
    });

    test('Android keeps over non-Android (antisymmetric)', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'android',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.2:4242',
          peerPlatform: 'ios',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.3:4242',
        ),
        isFalse,
      );
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'ios',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.3:4242',
          peerPlatform: 'android',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.2:4242',
        ),
        isTrue,
      );
    });

    test('higher currentRound wins (antisymmetric)', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 3,
          localEndpoint: '10.0.0.2:4242',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.3:4242',
        ),
        isFalse,
      );
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.3:4242',
          peerPlatform: 'other',
          peerCurrentRound: 3,
          peerEndpoint: '10.0.0.2:4242',
        ),
        isTrue,
      );
    });

    test('lexicographic hostIp:port — greater keeps', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.9:4242',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.2:4242',
        ),
        isFalse,
      );
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.2:4242',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.9:4242',
        ),
        isTrue,
      );
    });

    test('full key tie — local keeps on both sides', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 2,
          localEndpoint: '10.0.0.5:4242',
          peerPlatform: 'other',
          peerCurrentRound: 2,
          peerEndpoint: '10.0.0.5:4242',
        ),
        isFalse,
      );
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 2,
          localEndpoint: '10.0.0.5:4242',
          peerPlatform: 'other',
          peerCurrentRound: 2,
          peerEndpoint: '10.0.0.5:4242',
        ),
        isFalse,
      );
    });

    test('missing TXT platform/round defaults (non-Android, round 0)', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'android',
          localCurrentRound: 0,
          localEndpoint: '10.0.0.2:4242',
          peerPlatform: null,
          peerCurrentRound: null,
          peerEndpoint: '10.0.0.3:4242',
        ),
        isFalse,
      );
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 0,
          localEndpoint: '10.0.0.3:4242',
          peerPlatform: null,
          peerCurrentRound: null,
          peerEndpoint: '10.0.0.2:4242',
        ),
        // Same platform class (other), same round 0 → lex: 10.0.0.3 > 10.0.0.2 → keep
        isFalse,
      );
    });

    test('turnSequence ignored — divergent seats do not demote by index', () {
      // Same platform/round; local endpoint loses lex → yields by endpoint only.
      expect(
        shouldYieldHostingOnResume(
          hasPeerAd: true,
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.1:4242',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.9:4242',
        ),
        isTrue,
      );
      // Local would have higher turnSequence index historically, but keeps when
      // endpoint is lexicographically greater.
      expect(
        shouldYieldHostingOnResume(
          hasPeerAd: true,
          localPlayerId: 'p3',
          originalHostPlayerId: 'p1',
          localPlatform: 'other',
          localCurrentRound: 1,
          localEndpoint: '10.0.0.9:4242',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.1:4242',
        ),
        isFalse,
      );
    });

    test('ios vs other is platform-class tie (round/endpoint decide)', () {
      expect(
        shouldYieldDualHostHeal(
          localPlayerId: 'p2',
          originalHostPlayerId: 'p1',
          localPlatform: 'ios',
          localCurrentRound: 2,
          localEndpoint: '10.0.0.2:1',
          peerPlatform: 'other',
          peerCurrentRound: 1,
          peerEndpoint: '10.0.0.9:9',
        ),
        isFalse,
      );
    });
  });

  group('DiscoveredRoom platform/currentRound', () {
    test('copyWith preserves and clears optional heal fields', () {
      const room = DiscoveredRoom(
        roomId: 'r1',
        displayName: 'A',
        hostIp: '1.1.1.1',
        port: 9,
        platform: 'android',
        currentRound: 4,
      );
      expect(room.endpointKey, '1.1.1.1:9');
      final kept = room.copyWith(displayName: 'B');
      expect(kept.platform, 'android');
      expect(kept.currentRound, 4);
      final cleared = room.copyWith(clearPlatform: true, clearCurrentRound: true);
      expect(cleared.platform, isNull);
      expect(cleared.currentRound, isNull);
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
