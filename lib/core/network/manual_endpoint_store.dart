import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted manual `host:port` endpoint for LAN fallback.
class ManualEndpoint {
  const ManualEndpoint({
    required this.host,
    required this.port,
    this.label,
  });

  final String host;
  final int port;
  final String? label;

  String get key => '$host:$port';

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        if (label != null) 'label': label,
      };

  factory ManualEndpoint.fromJson(Map<String, dynamic> json) {
    return ManualEndpoint(
      host: json['host'] as String,
      port: json['port'] as int,
      label: json['label'] as String?,
    );
  }
}

/// SharedPreferences-backed store for manual LAN endpoints.
class ManualEndpointStore {
  ManualEndpointStore(this._preferences);

  static const _storageKey = 'manual_lan_endpoints';

  final SharedPreferences _preferences;

  static Future<ManualEndpointStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return ManualEndpointStore(preferences);
  }

  List<ManualEndpoint> loadAll() {
    final raw = _preferences.getStringList(_storageKey) ?? [];
    return raw
        .map((entry) => ManualEndpoint.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> saveAll(List<ManualEndpoint> endpoints) async {
    final encoded = endpoints.map((e) => jsonEncode(e.toJson())).toList();
    await _preferences.setStringList(_storageKey, encoded);
  }

  Future<void> add(ManualEndpoint endpoint) async {
    final endpoints = loadAll();
    endpoints.removeWhere((item) => item.key == endpoint.key);
    endpoints.insert(0, endpoint);
    await saveAll(endpoints);
  }

  Future<void> remove(ManualEndpoint endpoint) async {
    final endpoints = loadAll()
      ..removeWhere((item) => item.key == endpoint.key);
    await saveAll(endpoints);
  }
}
