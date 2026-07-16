import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:turnos_juegos/core/network/game_resume_store.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

void main() {
  test('GameResumeEntry.copyWith updates endpoint without changing seat', () {
    const entry = GameResumeEntry(
      roomId: 'r1',
      playerId: 'seat-b',
      deviceId: 'dev-b',
      host: '10.0.0.1',
      port: 1111,
      originalHostPlayerId: 'seat-a',
    );

    final updated = entry.copyWith(host: '10.0.0.9', port: 2222);
    expect(updated.playerId, 'seat-b');
    expect(updated.host, '10.0.0.9');
    expect(updated.port, 2222);
    expect(updated.originalHostPlayerId, 'seat-a');
  });

  test('HostDemotionResume carries seat and reclaim endpoint', () {
    const hint = HostDemotionResume(
      roomId: 'r1',
      seatPlayerId: 'seat-b',
      host: '10.0.0.50',
      port: 5555,
      formerListenHost: '10.0.0.2',
      formerListenPort: 9999,
    );
    expect(hint.seatPlayerId, isNot(hint.host));
    expect(hint.host, '10.0.0.50');
    expect(hint.formerListenHost, '10.0.0.2');
  });

  test('resume store round-trips seat without forcing self host', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await GameResumeStore.create();
    await store.save(
      const GameResumeEntry(
        roomId: 'r1',
        playerId: 'seat-b',
        deviceId: 'dev-b',
        originalHostPlayerId: 'seat-a',
      ),
    );
    final loaded = store.load();
    expect(loaded?.playerId, 'seat-b');
    expect(loaded?.host, isNull);
    expect(loaded?.port, isNull);
  });
}
