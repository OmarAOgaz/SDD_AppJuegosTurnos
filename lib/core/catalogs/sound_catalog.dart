/// Catalog entry for a player turn sound.
class CatalogSound {
  const CatalogSound({
    required this.id,
    required this.displayName,
    required this.assetPath,
  });

  final String id;
  final String displayName;

  /// Asset path under `assets/` (mute-safe stub until real tones land).
  final String assetPath;
}

/// Eight turn sounds — all map to the same silent stub in PR1.
class SoundCatalog {
  SoundCatalog._();

  static const String _stubAsset = 'assets/sounds/sound_stub.wav';

  static const List<CatalogSound> all = [
    CatalogSound(id: 'sound_1', displayName: 'Sonido 1', assetPath: _stubAsset),
    CatalogSound(id: 'sound_2', displayName: 'Sonido 2', assetPath: _stubAsset),
    CatalogSound(id: 'sound_3', displayName: 'Sonido 3', assetPath: _stubAsset),
    CatalogSound(id: 'sound_4', displayName: 'Sonido 4', assetPath: _stubAsset),
    CatalogSound(id: 'sound_5', displayName: 'Sonido 5', assetPath: _stubAsset),
    CatalogSound(id: 'sound_6', displayName: 'Sonido 6', assetPath: _stubAsset),
    CatalogSound(id: 'sound_7', displayName: 'Sonido 7', assetPath: _stubAsset),
    CatalogSound(id: 'sound_8', displayName: 'Sonido 8', assetPath: _stubAsset),
  ];

  static const defaultPreferredIds = ['sound_1', 'sound_2', 'sound_3'];

  static CatalogSound? byId(String id) {
    for (final entry in all) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  static List<String> allIds() => all.map((entry) => entry.id).toList();
}
