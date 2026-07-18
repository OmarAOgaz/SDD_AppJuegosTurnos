import '../catalogs/color_catalog.dart';
import '../catalogs/sound_catalog.dart';

/// Catalog id with whether another player currently holds it.
///
/// All catalog ids are always included so sheets can show taken options
/// struck through instead of omitting them.
typedef PickerOption = ({String id, bool isTaken});

/// All color options; [ownColorId] is never reported as taken.
List<PickerOption> colorPickerOptions({
  required Set<String> takenColorIds,
  String? ownColorId,
}) {
  return _pickerOptions(
    takenIds: takenColorIds,
    ownId: ownColorId,
    allIds: ColorCatalog.allIds(),
  );
}

/// All sound options; [ownSoundId] is never reported as taken.
List<PickerOption> soundPickerOptions({
  required Set<String> takenSoundIds,
  String? ownSoundId,
}) {
  return _pickerOptions(
    takenIds: takenSoundIds,
    ownId: ownSoundId,
    allIds: SoundCatalog.allIds(),
  );
}

List<PickerOption> _pickerOptions({
  required Set<String> takenIds,
  required String? ownId,
  required List<String> allIds,
}) {
  return [
    for (final id in allIds)
      (id: id, isTaken: takenIds.contains(id) && id != ownId),
  ];
}
