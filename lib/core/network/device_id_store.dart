import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _deviceIdKey = 'device_id';

/// Stable per-device identifier for heartbeat and reconnect.
class DeviceIdStore {
  DeviceIdStore(this._preferences, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final SharedPreferences _preferences;
  final Uuid _uuid;

  static Future<DeviceIdStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return DeviceIdStore(preferences);
  }

  String getOrCreate() {
    final existing = _preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    unawaited(_preferences.setString(_deviceIdKey, created));
    return created;
  }
}
