import '../models/game_phase.dart';

/// Immutable state captured by the caller from one coherent game-state read.
class TurnInfoSnapshot {
  const TurnInfoSnapshot({
    required this.gamePhase,
    required this.localPlayerId,
    required this.activePlayerId,
    required this.activePlayerName,
    required this.activePlayerColorId,
  });

  final GameRoomPhase gamePhase;
  final String? localPlayerId;
  final String? activePlayerId;
  final String? activePlayerName;
  final String? activePlayerColorId;
}

/// Display-only output: it exposes no turn or panel mutation capability.
sealed class TurnInfoPresentation {
  const TurnInfoPresentation({required this.capturedAt});

  final DateTime capturedAt;
}

class OwnTurnPresentation extends TurnInfoPresentation {
  const OwnTurnPresentation({required super.capturedAt});

  String get message => 'Es tu turno!!';
}

class WhoseTurnPresentation extends TurnInfoPresentation {
  const WhoseTurnPresentation({
    required super.capturedAt,
    required this.activePlayerName,
    required this.activeColorId,
  });

  final String activePlayerName;
  final String? activeColorId;
}

/// Pure resolver shared by tap and motion dispatch. Invalid state is a no-op.
TurnInfoPresentation? resolveTurnInfoPresentation({
  required TurnInfoSnapshot snapshot,
  required DateTime capturedAt,
}) {
  if (snapshot.gamePhase != GameRoomPhase.inGame) {
    return null;
  }

  final localId = snapshot.localPlayerId?.trim();
  final activeId = snapshot.activePlayerId?.trim();
  final activeName = snapshot.activePlayerName;
  if (localId == null ||
      localId.isEmpty ||
      activeId == null ||
      activeId.isEmpty ||
      activeName == null ||
      activeName.trim().isEmpty) {
    return null;
  }

  if (localId == activeId) {
    return OwnTurnPresentation(capturedAt: capturedAt);
  }

  return WhoseTurnPresentation(
    capturedAt: capturedAt,
    activePlayerName: activeName,
    activeColorId: snapshot.activePlayerColorId,
  );
}
