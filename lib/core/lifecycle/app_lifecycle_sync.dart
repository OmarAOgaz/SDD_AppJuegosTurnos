import 'package:flutter/widgets.dart';

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
