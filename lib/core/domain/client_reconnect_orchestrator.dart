import '../constants/network_constants.dart';
import '../models/discovered_room.dart';
import 'room_discovery.dart';

/// Recovery action for a client that lost its socket mid-game.
enum ClientRecoveryAction {
  /// Keep TCP retry; host may still be alive but not yet visible on browse.
  keepRetrying,

  /// mDNS (or equivalent) shows the room — reconnect, do not succeed.
  reconnectToEndpoint,

  /// Room not advertised for long enough — peer-local host succession.
  runHostSuccession,
}

/// Decides in-game client recovery vs host succession using mDNS liveness.
class ClientReconnectOrchestrator {
  ClientReconnectOrchestrator._();

  static ClientRecoveryAction decide({
    required DiscoveredRoom? mdnsMatch,
    required Duration unreachableDuration,
    String? lastKnownHost,
    int? lastKnownPort,
    bool isForeground = true,
    Duration hostLossGrace = const Duration(milliseconds: kHostLossGraceMs),
  }) {
    // Non-foreground (paused/inactive/hidden): never elect — keep retrying only.
    if (!isForeground) {
      return ClientRecoveryAction.keepRetrying;
    }

    if (mdnsMatch != null &&
        lastKnownHost != null &&
        lastKnownPort != null &&
        !isSameRoomEndpoint(
          mdnsMatch,
          host: lastKnownHost,
          port: lastKnownPort,
        )) {
      return ClientRecoveryAction.reconnectToEndpoint;
    }

    if (mdnsMatch != null) {
      return unreachableDuration >= hostLossGrace
          ? ClientRecoveryAction.reconnectToEndpoint
          : ClientRecoveryAction.keepRetrying;
    }

    if (unreachableDuration >= hostLossGrace) {
      return ClientRecoveryAction.runHostSuccession;
    }
    return ClientRecoveryAction.keepRetrying;
  }
}
