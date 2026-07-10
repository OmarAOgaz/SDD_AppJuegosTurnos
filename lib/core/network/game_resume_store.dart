import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local identity for resuming an in-progress game seat.
class GameResumeEntry {
  const GameResumeEntry({
    required this.roomId,
    required this.playerId,
    required this.deviceId,
    this.host,
    this.port,
    this.originalHostPlayerId,
  });

  final String roomId;
  final String playerId;
  final String deviceId;
  final String? host;
  final int? port;
  final String? originalHostPlayerId;

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'playerId': playerId,
        'deviceId': deviceId,
        if (host != null) 'host': host,
        if (port != null) 'port': port,
        if (originalHostPlayerId != null)
          'originalHostPlayerId': originalHostPlayerId,
      };

  factory GameResumeEntry.fromJson(Map<String, dynamic> json) {
    return GameResumeEntry(
      roomId: json['roomId'] as String,
      playerId: json['playerId'] as String,
      deviceId: json['deviceId'] as String,
      host: json['host'] as String?,
      port: json['port'] as int?,
      originalHostPlayerId: json['originalHostPlayerId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameResumeEntry &&
        other.roomId == roomId &&
        other.playerId == playerId &&
        other.deviceId == deviceId &&
        other.host == host &&
        other.port == port &&
        other.originalHostPlayerId == originalHostPlayerId;
  }

  @override
  int get hashCode => Object.hash(
        roomId,
        playerId,
        deviceId,
        host,
        port,
        originalHostPlayerId,
      );
}

/// SharedPreferences-backed store for in-game resume identity.
class GameResumeStore {
  GameResumeStore(this._preferences);

  static const storageKey = 'game_resume_entry';

  final SharedPreferences _preferences;

  static Future<GameResumeStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return GameResumeStore(preferences);
  }

  GameResumeEntry? load() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return GameResumeEntry.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  bool get hasEntry => load() != null;

  Future<void> save(GameResumeEntry entry) async {
    await _preferences.setString(storageKey, jsonEncode(entry.toJson()));
  }

  Future<void> clear() async {
    await _preferences.remove(storageKey);
  }
}
