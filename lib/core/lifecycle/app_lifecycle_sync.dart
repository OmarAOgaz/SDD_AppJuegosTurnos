import 'package:flutter/widgets.dart';

import '../network/game_resume_store.dart';
import '../network/game_socket_client.dart';

/// Whether lifecycle should treat the device as still in an active game session.
///
/// Active when resume identity exists OR the socket is up / reconnecting —
/// not only when [SocketClientState.connected].
bool isLifecycleSessionActive({
  required bool hasResumeIdentity,
  required SocketClientState? socketState,
}) {
  if (hasResumeIdentity) {
    return true;
  }
  if (socketState == null) {
    return false;
  }
  return socketState == SocketClientState.connected ||
      socketState == SocketClientState.connecting ||
      socketState == SocketClientState.reconnecting;
}

/// On app resume: SYNC if socket alive; otherwise reconnect then SYNC.
Future<void> syncOrReconnectSession({
  required GameSocketClient client,
  GameResumeEntry? resume,
}) async {
  if (client.localPlayerId == null && resume != null) {
    client.restoreLocalPlayerId(resume.playerId);
  }

  if (client.state == SocketClientState.connected) {
    client.sendSyncRequest();
    return;
  }

  final host = resume?.host ?? client.lastHost;
  final port = resume?.port ?? client.lastPort;
  if (host == null || port == null) {
    return;
  }

  await client.connect(host: host, port: port);
}

/// Observes app lifecycle and triggers resync when returning to foreground.
class AppLifecycleSync with WidgetsBindingObserver {
  AppLifecycleSync({
    required this.onResumed,
    required this.onPaused,
    required this.isSessionActive,
  });

  final VoidCallback onResumed;
  final VoidCallback onPaused;
  final bool Function() isSessionActive;

  bool _isAttached = false;

  void attach() {
    if (_isAttached) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isAttached = true;
  }

  void detach() {
    if (!_isAttached) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isSessionActive()) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        onPaused();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
