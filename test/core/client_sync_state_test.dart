import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
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
}
