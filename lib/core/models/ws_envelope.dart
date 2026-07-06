import 'dart:convert';

/// Typed JSON envelope for all WebSocket payloads.
class WsEnvelope {
  const WsEnvelope({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  factory WsEnvelope.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('WsEnvelope requires a non-empty type');
    }
    final payload = json['payload'];
    return WsEnvelope(
      type: type,
      payload: payload is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{},
    );
  }

  factory WsEnvelope.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('WsEnvelope root must be a JSON object');
    }
    return WsEnvelope.fromJson(decoded);
  }
}
