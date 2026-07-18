/// Catalog entry for a player turn sound.
class CatalogSound {
  const CatalogSound({
    required this.id,
    required this.displayName,
    required this.assetPath,
  });

  final String id;
  final String displayName;

  /// Flutter asset path including the `assets/` prefix.
  final String assetPath;
}

/// Eight audibly distinct lobby preview sounds.
class SoundCatalog {
  SoundCatalog._();

  // dart format off
  static const List<CatalogSound> all = [
    CatalogSound(id: 'sound_1', displayName: 'Clic claro', assetPath: 'assets/sounds/click_1.wav'),
    CatalogSound(id: 'sound_2', displayName: 'Clic grave', assetPath: 'assets/sounds/click_3.wav'),
    CatalogSound(id: 'sound_3', displayName: 'Deslizar suave', assetPath: 'assets/sounds/rollover_2.wav'),
    CatalogSound(id: 'sound_4', displayName: 'Deslizar brillante', assetPath: 'assets/sounds/rollover_5.wav'),
    CatalogSound(id: 'sound_5', displayName: 'Interruptor corto', assetPath: 'assets/sounds/switch_1.wav'),
    CatalogSound(id: 'sound_6', displayName: 'Interruptor elástico', assetPath: 'assets/sounds/switch_7.wav'),
    CatalogSound(id: 'sound_7', displayName: 'Interruptor metálico', assetPath: 'assets/sounds/switch_19.wav'),
    CatalogSound(id: 'sound_8', displayName: 'Interruptor digital', assetPath: 'assets/sounds/switch_32.wav'),
  ];
  // dart format on

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
