import '../constants/message_types.dart';
import '../models/ws_envelope.dart';

/// Client-side authoritative sync snapshot (stub timer fields later).
class ClientSyncState {
  const ClientSyncState({
    this.lastGameState,
    this.isBackgrounded = false,
    this.allowTimerInterpolation = true,
  });

  final Map<String, dynamic>? lastGameState;
  final bool isBackgrounded;
  final bool allowTimerInterpolation;

  int? get serverNow {
    final value = lastGameState?['serverNow'];
    return value is int ? value : null;
  }

  String? get gamePhaseWire => lastGameState?['gamePhase'] as String?;

  bool get isInActiveGame => gamePhaseWire == 'IN_GAME';

  ClientSyncState copyWith({
    Map<String, dynamic>? lastGameState,
    bool? isBackgrounded,
    bool? allowTimerInterpolation,
  }) {
    return ClientSyncState(
      lastGameState: lastGameState ?? this.lastGameState,
      isBackgrounded: isBackgrounded ?? this.isBackgrounded,
      allowTimerInterpolation:
          allowTimerInterpolation ?? this.allowTimerInterpolation,
    );
  }

  ClientSyncState applyEnvelope(WsEnvelope envelope) {
    if (envelope.type != MessageTypes.gameState) {
      return this;
    }
    return copyWith(
      lastGameState: Map<String, dynamic>.from(envelope.payload),
      allowTimerInterpolation: !isBackgrounded,
    );
  }

  ClientSyncState onBackground() {
    return copyWith(
      isBackgrounded: true,
      allowTimerInterpolation: false,
    );
  }

  ClientSyncState onForeground() {
    return copyWith(
      isBackgrounded: false,
      allowTimerInterpolation: true,
    );
  }
}
