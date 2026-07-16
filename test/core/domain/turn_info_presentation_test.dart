import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/turn_info_presentation.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';

final capturedAt = DateTime(2026, 7, 16, 21, 5);

TurnInfoSnapshot snapshot({
  GameRoomPhase phase = GameRoomPhase.inGame,
  String? localId = 'p1',
  String? activeId = 'p1',
  String? activeName = 'Ana',
  String? colorId = 'color_1',
}) {
  return TurnInfoSnapshot(
    gamePhase: phase,
    localPlayerId: localId,
    activePlayerId: activeId,
    activePlayerName: activeName,
    activePlayerColorId: colorId,
  );
}

TurnInfoPresentation? resolve(TurnInfoSnapshot value) =>
    resolveTurnInfoPresentation(snapshot: value, capturedAt: capturedAt);

void main() {
  test('resolves own turn with the dispatch-time snapshot', () {
    final result = resolve(
      snapshot(localId: ' p1 ', activeId: 'p1'),
    ) as OwnTurnPresentation;

    expect(result.capturedAt, capturedAt);
    expect(result.message, 'Es tu turno!!');
  });

  test('resolves whose turn without altering display-name spacing', () {
    final result = resolve(
      snapshot(localId: 'p2', activeName: ' Ana María ', colorId: 'color_3'),
    ) as WhoseTurnPresentation;

    expect(result.capturedAt, capturedAt);
    expect(result.activePlayerName, ' Ana María ');
    expect(result.activeColorId, 'color_3');
  });

  test('invalid or non-game snapshots are no-ops', () {
    final invalid = [
      snapshot(phase: GameRoomPhase.lobby),
      snapshot(phase: GameRoomPhase.betweenRounds),
      snapshot(phase: GameRoomPhase.ended),
      snapshot(localId: null),
      snapshot(localId: ''),
      snapshot(localId: ' \t'),
      snapshot(activeId: null),
      snapshot(activeId: ''),
      snapshot(activeId: '\n '),
      snapshot(activeName: null),
      snapshot(activeName: ''),
      snapshot(activeName: ' \t\n'),
    ];

    for (final value in invalid) {
      expect(resolve(value), isNull);
    }
  });
}
