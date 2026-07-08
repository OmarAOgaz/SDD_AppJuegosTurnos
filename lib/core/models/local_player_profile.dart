import '../catalogs/color_catalog.dart';
import '../catalogs/sound_catalog.dart';

/// Device-local defaults used when creating or joining a room.
class LocalPlayerProfile {
  const LocalPlayerProfile({
    required this.defaultDisplayName,
    required this.preferredColorIds,
    required this.preferredSoundIds,
  });

  final String defaultDisplayName;
  final List<String> preferredColorIds;
  final List<String> preferredSoundIds;

  static LocalPlayerProfile defaults() {
    return const LocalPlayerProfile(
      defaultDisplayName: 'Jugador',
      preferredColorIds: ColorCatalog.defaultPreferredIds,
      preferredSoundIds: SoundCatalog.defaultPreferredIds,
    );
  }

  bool get hasUsableDisplayName => defaultDisplayName.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is LocalPlayerProfile &&
        other.defaultDisplayName == defaultDisplayName &&
        _listEquals(other.preferredColorIds, preferredColorIds) &&
        _listEquals(other.preferredSoundIds, preferredSoundIds);
  }

  @override
  int get hashCode => Object.hash(
        defaultDisplayName,
        Object.hashAll(preferredColorIds),
        Object.hashAll(preferredSoundIds),
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  LocalPlayerProfile copyWith({
    String? defaultDisplayName,
    List<String>? preferredColorIds,
    List<String>? preferredSoundIds,
  }) {
    return LocalPlayerProfile(
      defaultDisplayName: defaultDisplayName ?? this.defaultDisplayName,
      preferredColorIds: preferredColorIds ?? this.preferredColorIds,
      preferredSoundIds: preferredSoundIds ?? this.preferredSoundIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultDisplayName': defaultDisplayName,
      'preferredColorIds': preferredColorIds,
      'preferredSoundIds': preferredSoundIds,
    };
  }

  factory LocalPlayerProfile.fromJson(Map<String, dynamic> json) {
    return LocalPlayerProfile(
      defaultDisplayName: json['defaultDisplayName'] as String? ?? '',
      preferredColorIds: _readStringList(
        json['preferredColorIds'],
        ColorCatalog.defaultPreferredIds,
      ),
      preferredSoundIds: _readStringList(
        json['preferredSoundIds'],
        SoundCatalog.defaultPreferredIds,
      ),
    );
  }

  static List<String> _readStringList(
    dynamic raw,
    List<String> fallback,
  ) {
    if (raw is! List) {
      return List<String>.from(fallback);
    }
    final values = raw.whereType<String>().toList();
    if (values.length < 3) {
      return List<String>.from(fallback);
    }
    return values.take(3).toList();
  }
}
