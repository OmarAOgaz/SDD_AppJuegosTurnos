import '../models/player.dart';

/// Copy and peer list for in-game session banners (reconnect + disconnect).
class GameSessionBannerTexts {
  const GameSessionBannerTexts({
    this.reconnectMessage,
    this.disconnectedPeers = const [],
    this.controlledPeers = const [],
  });

  static const String localReconnectMessage = 'Reconectando con el host…';

  /// Host-only control-banner suffix (hardcoded Spanish).
  static const String hostControlSuffix = ' — controlando su turno';

  final String? reconnectMessage;

  /// Seated peers with `connected=false` to show in the peer-disconnect banner.
  final List<Player> disconnectedPeers;

  /// Host-only disconnected seats this acting host controls.
  final List<Player> controlledPeers;

  bool get isEmpty =>
      reconnectMessage == null &&
      disconnectedPeers.isEmpty &&
      controlledPeers.isEmpty;

  /// Stable key for dismiss state — changes when the disconnected set changes.
  static String disconnectedPeersKey(Iterable<Player> peers) {
    final ids = peers.map((p) => p.playerId).where((id) => id.isNotEmpty).toList()
      ..sort();
    return ids.join(',');
  }

  /// Resolves banner content from socket state and seated player connectivity.
  static GameSessionBannerTexts resolve({
    required bool showLocalReconnect,
    required Iterable<Player> seatedPlayers,
    String? localPlayerId,
    bool excludeLocalFromPeerDisconnect = false,
    bool includeHostControlBanner = false,
  }) {
    final reconnectMessage =
        showLocalReconnect ? localReconnectMessage : null;

    final disconnected = <Player>[];
    final controlled = <Player>[];
    for (final player in seatedPlayers) {
      if (player.connected) {
        continue;
      }
      if (player.playerId.isEmpty) {
        continue;
      }
      if (excludeLocalFromPeerDisconnect &&
          localPlayerId != null &&
          player.playerId == localPlayerId) {
        continue;
      }
      disconnected.add(player);
      if (includeHostControlBanner &&
          (localPlayerId == null || player.playerId != localPlayerId)) {
        controlled.add(player);
      }
    }

    return GameSessionBannerTexts(
      reconnectMessage: reconnectMessage,
      disconnectedPeers: disconnected,
      controlledPeers: controlled,
    );
  }

  /// Display label for a seated player in banner copy.
  static String playerLabel(Player player) {
    final name = player.displayName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return player.playerId;
  }

  /// Spanish name join used by host-control copy (`Ana y Luis`).
  static String joinPlayerLabels(Iterable<Player> peers) {
    final labels = peers.map(playerLabel).where((n) => n.isNotEmpty).toList();
    if (labels.isEmpty) {
      return '';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels[0]} y ${labels[1]}';
    }
    return '${labels.sublist(0, labels.length - 1).join(', ')} y ${labels.last}';
  }
}
