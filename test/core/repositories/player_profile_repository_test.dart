import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/core/models/local_player_profile.dart';
import 'package:turnos_juegos/core/repositories/player_profile_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns defaults when nothing saved', () async {
    final repository = await PlayerProfileRepository.create();
    final profile = repository.load();
    expect(profile.defaultDisplayName, 'Jugador');
    expect(profile.preferredColorIds, LocalPlayerProfile.defaults().preferredColorIds);
  });

  test('save and load round-trips profile', () async {
    final repository = await PlayerProfileRepository.create();
    const profile = LocalPlayerProfile(
      defaultDisplayName: 'Ana',
      preferredColorIds: ['color_4', 'color_5', 'color_6'],
      preferredSoundIds: ['sound_4', 'sound_5', 'sound_6'],
    );
    await repository.save(profile);
    expect(repository.load(), profile);
  });
}
