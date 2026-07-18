import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/catalogs/sound_catalog.dart';
import 'package:turnos_juegos/core/domain/eligible_picker.dart';

void main() {
  test('colorPickerOptions: all ids; only others taken', () {
    final options = colorPickerOptions(
      takenColorIds: const {'color_1', 'color_2'},
      ownColorId: 'color_2',
    );
    expect(options.length, ColorCatalog.allIds().length);
    bool taken(String id) => options.firstWhere((o) => o.id == id).isTaken;
    expect(taken('color_1'), isTrue);
    expect(taken('color_2'), isFalse);
    expect(taken('color_3'), isFalse);
  });

  test('soundPickerOptions: all ids; only others taken', () {
    final options = soundPickerOptions(
      takenSoundIds: const {'sound_3', 'sound_4'},
      ownSoundId: 'sound_4',
    );
    expect(options.length, SoundCatalog.allIds().length);
    bool taken(String id) => options.firstWhere((o) => o.id == id).isTaken;
    expect(taken('sound_3'), isTrue);
    expect(taken('sound_4'), isFalse);
  });
}
