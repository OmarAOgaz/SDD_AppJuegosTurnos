import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/turn_state.dart';
import 'package:turnos_juegos/core/models/ws_envelope.dart';

void main() {
  test('applyEnvelope stores GAME_STATE without replay flag', () {
    const state = ClientSyncState();
    final updated = state.applyEnvelope(
      const WsEnvelope(
        type: MessageTypes.gameState,
        payload: {
          'serverNow': 123456,
          'gamePhase': 'IN_GAME',
          'turnStartedAt': 120000,
          'currentRoundTurnDurationSeconds': 60,
        },
      ),
    );

    expect(updated.serverNowAtReceive, 123456);
    expect(updated.isInActiveGame, isTrue);
    expect(updated.allowTimerInterpolation, isTrue);
    expect(updated.receivedAtMs, isNotNull);
  });

  test('interpolates warning phase from remaining time', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = ClientSyncState(
      lastGameState: {
        'gamePhase': 'IN_GAME',
        'serverNow': now,
        'turnStartedAt': now - 50000,
        'currentRoundTurnDurationSeconds': 60,
      },
      receivedAtMs: now,
    );
    expect(state.remainingSeconds(), lessThanOrEqualTo(15));
    expect(state.interpolatedPhase().wireValue, isIn(['WARNING', 'EXCEEDED']));
  });

  group('betweenRoundsElapsedSeconds', () {
    const stamp = 1_000_000;
    const serverNow = 1_012_500; // 12.5s after stamp

    ClientSyncState breakSync({
      int? betweenRoundsEnteredAt = stamp,
      int serverNowMs = serverNow,
      String gamePhase = 'BETWEEN_ROUNDS',
      bool allowInterpolation = false,
    }) {
      return ClientSyncState(
        lastGameState: {
          'gamePhase': gamePhase,
          'serverNow': serverNowMs,
          if (betweenRoundsEnteredAt != null)
            'betweenRoundsEnteredAt': betweenRoundsEnteredAt,
        },
        allowTimerInterpolation: allowInterpolation,
        receivedAtMs: serverNowMs,
      );
    }

    test('returns null when not BETWEEN_ROUNDS', () {
      final state = breakSync(gamePhase: GameRoomPhase.inGame.wireValue);
      expect(state.betweenRoundsElapsedSeconds(), isNull);
    });

    test('returns null when stamp is missing', () {
      final state = breakSync(betweenRoundsEnteredAt: null);
      expect(state.betweenRoundsElapsedSeconds(), isNull);
    });

    test('floors elapsed from stamp and estimatedServerNowMs', () {
      final state = breakSync();
      // 12500ms → floor → 12s
      expect(state.betweenRoundsElapsedSeconds(), 12);
    });

    test('clamps negative drift to zero', () {
      final state = breakSync(serverNowMs: stamp - 5000);
      expect(state.betweenRoundsElapsedSeconds(), 0);
    });

    test('peers with shared snapshot match elapsed', () {
      final peerA = breakSync();
      final peerB = breakSync();
      expect(
        peerA.betweenRoundsElapsedSeconds(),
        peerB.betweenRoundsElapsedSeconds(),
      );
      expect(peerA.betweenRoundsElapsedSeconds(), 12);
    });
  });

  group('return-turn pause interpolation', () {
    test('turnPausedAt freezes remaining despite interpolated serverNow', () {
      const startedAt = 1_000_000;
      const pausedAt = startedAt + 10_000;
      const state = ClientSyncState(
        lastGameState: {
          'gamePhase': 'IN_GAME',
          'serverNow': pausedAt,
          'turnStartedAt': startedAt,
          'turnPausedAt': pausedAt,
          'currentRoundTurnDurationSeconds': 60,
          'pendingReturnRequest': {
            'requestId': 'p2@$pausedAt',
            'requesterPlayerId': 'p2',
            'previousPlayerId': 'host-1',
            'requestedAt': pausedAt,
            'expiresAt': pausedAt + 10_000,
          },
        },
        receivedAtMs: pausedAt - 20_000,
        allowTimerInterpolation: true,
      );

      expect(state.turnPausedAtMs, pausedAt);
      expect(state.hasPendingReturnRequest, isTrue);
      expect(state.pendingReturnRequest?.requesterPlayerId, 'p2');
      expect(state.remainingSeconds(), 50);
      expect(state.interpolatedPhase(), TurnPhase.normal);
    });

    test('absent return fields mean no pending and clock interpolates', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = ClientSyncState(
        lastGameState: {
          'gamePhase': 'IN_GAME',
          'serverNow': now,
          'turnStartedAt': now - 5_000,
          'currentRoundTurnDurationSeconds': 60,
        },
        receivedAtMs: now,
      );

      expect(state.turnPausedAtMs, isNull);
      expect(state.pendingReturnRequest, isNull);
      expect(state.lastReturnOutcome, isNull);
      expect(state.hasPendingReturnRequest, isFalse);
      expect(state.remainingSeconds(), closeTo(55, 1));
    });

    test('lastReturnOutcome getter parses expired result', () {
      const state = ClientSyncState(
        lastGameState: {
          'gamePhase': 'IN_GAME',
          'lastReturnOutcome': {
            'requestId': 'p2@1',
            'result': 'expired',
            'requesterPlayerId': 'p2',
            'previousPlayerId': 'host-1',
          },
        },
      );
      expect(state.lastReturnOutcome?.result, ReturnOutcomeResult.expired);
      expect(state.lastReturnOutcome?.requesterPlayerId, 'p2');
    });
  });
}
