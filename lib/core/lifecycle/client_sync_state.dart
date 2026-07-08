import '../constants/message_types.dart';
import '../domain/turn_engine.dart';
import '../models/game_phase.dart';
import '../models/ws_envelope.dart';

/// Client-side authoritative sync snapshot with timer interpolation.
class ClientSyncState {
  const ClientSyncState({
    this.lastGameState,
    this.isBackgrounded = false,
    this.allowTimerInterpolation = true,
    this.receivedAtMs,
  });

  final Map<String, dynamic>? lastGameState;
  final bool isBackgrounded;
  final bool allowTimerInterpolation;
  final int? receivedAtMs;

  int? get serverNowAtReceive {
    final value = lastGameState?['serverNow'];
    return value is int ? value : null;
  }

  String? get gamePhaseWire => lastGameState?['gamePhase'] as String?;

  bool get isInActiveGame => gamePhaseWire == GameRoomPhase.inGame.wireValue;

  bool get isEnded => gamePhaseWire == GameRoomPhase.ended.wireValue;

  int estimatedServerNowMs() {
    final base = serverNowAtReceive;
    final received = receivedAtMs;
    if (base == null || received == null || !allowTimerInterpolation) {
      return base ?? DateTime.now().millisecondsSinceEpoch;
    }
    return base + (DateTime.now().millisecondsSinceEpoch - received);
  }

  int? remainingSeconds() {
    if (!isInActiveGame || lastGameState == null) {
      return null;
    }
    final startedAt = lastGameState!['turnStartedAt'];
    final duration = lastGameState!['currentRoundTurnDurationSeconds'] ??
        lastGameState!['currentRoundDurationSeconds'];
    if (startedAt is! int || duration is! int) {
      return null;
    }
    final elapsedMs = estimatedServerNowMs() - startedAt;
    final remainingMs = duration * 1000 - elapsedMs;
    return (remainingMs / 1000).ceil();
  }

  TurnPhase interpolatedPhase() {
    if (!isInActiveGame) {
      return TurnPhase.normal;
    }
    final remaining = remainingSeconds();
    if (remaining == null) {
      return TurnPhase.normal;
    }
    if (remaining <= 0) {
      return TurnPhase.exceeded;
    }
    if (remaining <= TurnEngine.warningThresholdSeconds) {
      return TurnPhase.warning;
    }
    return TurnPhase.normal;
  }

  ClientSyncState copyWith({
    Map<String, dynamic>? lastGameState,
    bool? isBackgrounded,
    bool? allowTimerInterpolation,
    int? receivedAtMs,
  }) {
    return ClientSyncState(
      lastGameState: lastGameState ?? this.lastGameState,
      isBackgrounded: isBackgrounded ?? this.isBackgrounded,
      allowTimerInterpolation:
          allowTimerInterpolation ?? this.allowTimerInterpolation,
      receivedAtMs: receivedAtMs ?? this.receivedAtMs,
    );
  }

  ClientSyncState applyEnvelope(WsEnvelope envelope) {
    if (envelope.type != MessageTypes.gameState) {
      return this;
    }
    return copyWith(
      lastGameState: Map<String, dynamic>.from(envelope.payload),
      receivedAtMs: DateTime.now().millisecondsSinceEpoch,
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
