import '../models/player.dart';

/// Copy and peer list for in-game session banners (reconnect + disconnect).
class GameSessionBannerTexts {
  const GameSessionBannerTexts({
    this.reconnectMessage,
    this.disconnectedPeers = const [],
  });

  static const String localReconnectMessage = 'Reconectando con el host…';

  final String? reconnectMessage;

  /// Seated peers with `connected=false` to show in the peer-disconnect banner.
  final List<Player> disconnectedPeers;

  bool get isEmpty =>
      reconnectMessage == null && disconnectedPeers.isEmpty;

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
  }) {
    final reconnectMessage =
        showLocalReconnect ? localReconnectMessage : null;

    final disconnected = <Player>[];
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
    }

    return GameSessionBannerTexts(
      reconnectMessage: reconnectMessage,
      disconnectedPeers: disconnected,
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
}
