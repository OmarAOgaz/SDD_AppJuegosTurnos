import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/catalogs/sound_catalog.dart';
import 'package:turnos_juegos/core/domain/eligible_picker.dart';

void main() {
  group('eligibleColorIds', () {
    test('omits taken colors except own assignment', () {
      final eligible = eligibleColorIds(
        takenColorIds: const {'color_1', 'color_2'},
        ownColorId: 'color_2',
      );
      expect(eligible, contains('color_2'));
      expect(eligible, isNot(contains('color_1')));
      expect(eligible.length, ColorCatalog.allIds().length - 1);
    });
  });

  group('eligibleSoundIds', () {
    test('omits taken sounds except own assignment', () {
      final eligible = eligibleSoundIds(
        takenSoundIds: const {'sound_3', 'sound_4'},
        ownSoundId: 'sound_4',
      );
      expect(eligible, contains('sound_4'));
      expect(eligible, isNot(contains('sound_3')));
      expect(eligible.length, SoundCatalog.allIds().length - 1);
    });
  });
}
