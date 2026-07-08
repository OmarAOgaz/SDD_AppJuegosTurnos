import '../catalogs/color_catalog.dart';
import '../catalogs/sound_catalog.dart';

/// Catalog ids a player may pick: free ids plus their current assignment.
List<String> eligibleColorIds({
  required Set<String> takenColorIds,
  String? ownColorId,
}) {
  return _eligibleIds(
    takenIds: takenColorIds,
    ownId: ownColorId,
    allIds: ColorCatalog.allIds(),
  );
}

/// Catalog ids a player may pick: free ids plus their current assignment.
List<String> eligibleSoundIds({
  required Set<String> takenSoundIds,
  String? ownSoundId,
}) {
  return _eligibleIds(
    takenIds: takenSoundIds,
    ownId: ownSoundId,
    allIds: SoundCatalog.allIds(),
  );
}

List<String> _eligibleIds({
  required Set<String> takenIds,
  required String? ownId,
  required List<String> allIds,
}) {
  final eligible = <String>[];
  for (final id in allIds) {
    if (!takenIds.contains(id) || id == ownId) {
      eligible.add(id);
    }
  }
  return eligible;
}
