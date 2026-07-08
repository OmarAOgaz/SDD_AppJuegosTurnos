import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/catalogs/sound_catalog.dart';
import 'package:turnos_juegos/core/domain/preference_assignment.dart';

void main() {
  group('assignJoinColorId', () {
    test('picks first free preferred color', () {
      final assigned = assignJoinColorId(
        preferredColorIds: const ['color_1', 'color_2', 'color_3'],
        takenColorIds: const {'color_1'},
      );
      expect(assigned, 'color_2');
    });

    test('falls back to any free catalog color', () {
      final assigned = assignJoinColorId(
        preferredColorIds: const ['color_1', 'color_2', 'color_3'],
        takenColorIds: ColorCatalog.allIds().toSet(),
      );
      expect(assigned, 'color_1');
    });
  });

  group('assignJoinSoundId', () {
    test('is independent from color assignment', () {
      final color = assignJoinColorId(
        preferredColorIds: const ['color_1', 'color_2', 'color_3'],
        takenColorIds: const {'color_1', 'color_2', 'color_3'},
      );
      final sound = assignJoinSoundId(
        preferredSoundIds: const ['sound_1', 'sound_2', 'sound_3'],
        takenSoundIds: const {'sound_2'},
      );
      expect(color, 'color_4');
      expect(sound, 'sound_1');
    });

    test('uses second preference when first sound is taken', () {
      final assigned = assignJoinSoundId(
        preferredSoundIds: SoundCatalog.defaultPreferredIds,
        takenSoundIds: const {'sound_1'},
      );
      expect(assigned, 'sound_2');
    });
  });
}
