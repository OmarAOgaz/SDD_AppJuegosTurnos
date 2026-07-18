/// Seated participant in a game room.
class Player {
  Player({
    required this.playerId,
    required this.displayName,
    required this.colorId,
    required this.soundId,
    required this.deviceId,
    this.slotNumber = 0,
    this.connected = true,
    this.exceededTurnCount = 0,
    this.totalExceededMs = 0,
    this.turnCount = 0,
    this.totalTurnMs = 0,
  });

  final String playerId;
  String displayName;
  String colorId;
  String soundId;
  final String deviceId;
  int slotNumber;
  bool connected;
  int exceededTurnCount;
  int totalExceededMs;
  int turnCount;
  int totalTurnMs;

  Player copyWith({
    String? displayName,
    String? colorId,
    String? soundId,
    int? slotNumber,
    bool? connected,
    int? exceededTurnCount,
    int? totalExceededMs,
    int? turnCount,
    int? totalTurnMs,
  }) {
    return Player(
      playerId: playerId,
      displayName: displayName ?? this.displayName,
      colorId: colorId ?? this.colorId,
      soundId: soundId ?? this.soundId,
      deviceId: deviceId,
      slotNumber: slotNumber ?? this.slotNumber,
      connected: connected ?? this.connected,
      exceededTurnCount: exceededTurnCount ?? this.exceededTurnCount,
      totalExceededMs: totalExceededMs ?? this.totalExceededMs,
      turnCount: turnCount ?? this.turnCount,
      totalTurnMs: totalTurnMs ?? this.totalTurnMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'colorId': colorId,
      'soundId': soundId,
      'deviceId': deviceId,
      'slotNumber': slotNumber,
      'connected': connected,
      'exceededTurnCount': exceededTurnCount,
      'totalExceededMs': totalExceededMs,
      'turnCount': turnCount,
      'totalTurnMs': totalTurnMs,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      playerId: json['playerId'] as String,
      displayName: json['displayName'] as String? ?? '',
      colorId: json['colorId'] as String? ?? '',
      soundId: json['soundId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      slotNumber: json['slotNumber'] as int? ?? 0,
      connected: json['connected'] as bool? ?? true,
      exceededTurnCount: json['exceededTurnCount'] as int? ?? 0,
      totalExceededMs: json['totalExceededMs'] as int? ?? 0,
      turnCount: json['turnCount'] as int? ?? 0,
      totalTurnMs: json['totalTurnMs'] as int? ?? 0,
    );
  }
}
