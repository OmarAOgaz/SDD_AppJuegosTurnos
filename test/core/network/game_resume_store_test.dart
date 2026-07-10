import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/core/network/game_resume_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing saved', () async {
    final store = await GameResumeStore.create();
    expect(store.load(), isNull);
    expect(store.hasEntry, isFalse);
  });

  test('save and load round-trips resume entry', () async {
    final store = await GameResumeStore.create();
    const entry = GameResumeEntry(
      roomId: 'room-1',
      playerId: 'player-1',
      deviceId: 'device-1',
      host: '192.168.1.10',
      port: 8080,
      originalHostPlayerId: 'host-1',
    );

    await store.save(entry);

    expect(store.load(), entry);
    expect(store.hasEntry, isTrue);
  });

  test('clear removes resume entry', () async {
    final store = await GameResumeStore.create();
    await store.save(
      const GameResumeEntry(
        roomId: 'room-1',
        playerId: 'player-1',
        deviceId: 'device-1',
      ),
    );

    await store.clear();

    expect(store.load(), isNull);
    expect(store.hasEntry, isFalse);
  });
}
