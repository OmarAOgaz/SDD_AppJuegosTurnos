import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/models/ws_envelope.dart';

void main() {
  test('applyEnvelope stores GAME_STATE without replay flag', () {
    const state = ClientSyncState();
    final updated = state.applyEnvelope(
      const WsEnvelope(
        type: 'GAME_STATE',
        payload: {
          'serverNow': 123456,
          'gamePhase': 'IN_GAME',
        },
      ),
    );

    expect(updated.serverNow, 123456);
    expect(updated.isInActiveGame, isTrue);
    expect(updated.allowTimerInterpolation, isTrue);
  });
}
