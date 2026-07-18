import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
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
}
