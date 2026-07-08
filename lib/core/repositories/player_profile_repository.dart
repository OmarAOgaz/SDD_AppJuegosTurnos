import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_player_profile.dart';

const _profileKey = 'local_player_profile';

/// Persists device-local player defaults for create/join flows.
class PlayerProfileRepository {
  PlayerProfileRepository(this._preferences);

  final SharedPreferences _preferences;

  static Future<PlayerProfileRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return PlayerProfileRepository(preferences);
  }

  LocalPlayerProfile load() {
    final raw = _preferences.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      return LocalPlayerProfile.defaults();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LocalPlayerProfile.fromJson(json);
    } catch (_) {
      return LocalPlayerProfile.defaults();
    }
  }

  Future<void> save(LocalPlayerProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}
