import 'package:flutter/material.dart';

import 'app_lifecycle_sync.dart';

/// Registers lifecycle observer for an active spike/game session.
class SessionLifecycleListener extends StatefulWidget {
  const SessionLifecycleListener({
    super.key,
    required this.child,
    required this.isSessionActive,
    required this.onResumed,
    required this.onPaused,
  });

  final Widget child;
  final bool Function() isSessionActive;
  final VoidCallback onResumed;
  final VoidCallback onPaused;

  @override
  State<SessionLifecycleListener> createState() =>
      _SessionLifecycleListenerState();
}

class _SessionLifecycleListenerState extends State<SessionLifecycleListener> {
  late final AppLifecycleSync _sync;

  @override
  void initState() {
    super.initState();
    _sync = AppLifecycleSync(
      isSessionActive: widget.isSessionActive,
      onResumed: widget.onResumed,
      onPaused: widget.onPaused,
    );
    _sync.attach();
  }

  @override
  void dispose() {
    _sync.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
