import '../catalogs/color_catalog.dart';
import '../catalogs/sound_catalog.dart';

/// Assigns the first available catalog id from preference list, then any free id.
String assignPreferredId({
  required List<String> preferredIds,
  required Set<String> takenIds,
  required List<String> allIds,
}) {
  for (final id in preferredIds) {
    if (!takenIds.contains(id)) {
      return id;
    }
  }
  for (final id in allIds) {
    if (!takenIds.contains(id)) {
      return id;
    }
  }
  return preferredIds.first;
}

/// Join-time color assignment (independent from sound).
String assignJoinColorId({
  required List<String> preferredColorIds,
  required Set<String> takenColorIds,
}) {
  return assignPreferredId(
    preferredIds: preferredColorIds,
    takenIds: takenColorIds,
    allIds: ColorCatalog.allIds(),
  );
}

/// Join-time sound assignment (independent from color).
String assignJoinSoundId({
  required List<String> preferredSoundIds,
  required Set<String> takenSoundIds,
}) {
  return assignPreferredId(
    preferredIds: preferredSoundIds,
    takenIds: takenSoundIds,
    allIds: SoundCatalog.allIds(),
  );
}
