import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/turn_feedback.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';

void main() {
  group('resolveTurnFeedback', () {
    const nonInGamePhases = [
      GameRoomPhase.lobby,
      GameRoomPhase.betweenRounds,
      GameRoomPhase.ended,
    ];

    for (final gamePhase in nonInGamePhases) {
      for (final isActive in [true, false]) {
        for (final turnPhase in TurnPhase.values) {
          test(
            'outside inGame ($gamePhase, active=$isActive, $turnPhase) stays black',
            () {
              final visual = resolveTurnFeedback(
                isMyDeviceActive: isActive,
                gamePhase: gamePhase,
                phase: turnPhase,
                activeColorId: 'color_1',
              );
              expect(visual, TurnFeedbackVisual.black);
            },
          );
        }
      }
    }

    for (final turnPhase in TurnPhase.values) {
      test('inGame, non-active device stays black ($turnPhase)', () {
        final visual = resolveTurnFeedback(
          isMyDeviceActive: false,
          gamePhase: GameRoomPhase.inGame,
          phase: turnPhase,
          activeColorId: 'color_1',
        );
        expect(visual, TurnFeedbackVisual.black);
      });
    }

    test('inGame, active device, normal phase stays literal black (no tint)', () {
      final visual = resolveTurnFeedback(
        isMyDeviceActive: true,
        gamePhase: GameRoomPhase.inGame,
        phase: TurnPhase.normal,
        activeColorId: 'color_1',
      );
      expect(visual, TurnFeedbackVisual.black);
      expect(visual.colorId, isNull);
    });

    test('inGame, active device, warning phase flashes activeColorId', () {
      final visual = resolveTurnFeedback(
        isMyDeviceActive: true,
        gamePhase: GameRoomPhase.inGame,
        phase: TurnPhase.warning,
        activeColorId: 'color_2',
      );
      expect(visual.kind, TurnFeedbackKind.flashing);
      expect(visual.colorId, 'color_2');
    });

    test('inGame, active device, exceeded phase fixes activeColorId', () {
      final visual = resolveTurnFeedback(
        isMyDeviceActive: true,
        gamePhase: GameRoomPhase.inGame,
        phase: TurnPhase.exceeded,
        activeColorId: 'color_3',
      );
      expect(visual.kind, TurnFeedbackKind.fixed);
      expect(visual.colorId, 'color_3');
    });

    test('non-active device never flashes or fixes even at warning/exceeded', () {
      for (final turnPhase in [TurnPhase.warning, TurnPhase.exceeded]) {
        final visual = resolveTurnFeedback(
          isMyDeviceActive: false,
          gamePhase: GameRoomPhase.inGame,
          phase: turnPhase,
          activeColorId: 'color_4',
        );
        expect(visual, TurnFeedbackVisual.black);
      }
    });

    test('handles null activeColorId defensively without throwing', () {
      final visual = resolveTurnFeedback(
        isMyDeviceActive: true,
        gamePhase: GameRoomPhase.inGame,
        phase: TurnPhase.warning,
        activeColorId: null,
      );
      expect(visual.kind, TurnFeedbackKind.flashing);
      expect(visual.colorId, isNull);
    });
  });

  group('resolveTapIntent', () {
    test('inGame + active -> pass', () {
      expect(
        resolveTapIntent(
          isMyDeviceActive: true,
          gamePhase: GameRoomPhase.inGame,
        ),
        GestureIntent.pass,
      );
    });

    test('inGame + non-active -> showActiveToast', () {
      expect(
        resolveTapIntent(
          isMyDeviceActive: false,
          gamePhase: GameRoomPhase.inGame,
        ),
        GestureIntent.showActiveToast,
      );
    });

    test(
      'inGame + non-active + host pass for disconnected active -> pass',
      () {
        expect(
          resolveTapIntent(
            isMyDeviceActive: false,
            canHostPassForDisconnectedActive: true,
            gamePhase: GameRoomPhase.inGame,
          ),
          GestureIntent.pass,
        );
      },
    );

    test(
      'host pass for disconnect does not apply outside inGame',
      () {
        expect(
          resolveTapIntent(
            isMyDeviceActive: false,
            canHostPassForDisconnectedActive: true,
            gamePhase: GameRoomPhase.betweenRounds,
          ),
          GestureIntent.none,
        );
      },
    );

    for (final gamePhase in [
      GameRoomPhase.lobby,
      GameRoomPhase.betweenRounds,
      GameRoomPhase.ended,
    ]) {
      for (final isActive in [true, false]) {
        test('outside inGame ($gamePhase, active=$isActive) -> none', () {
          expect(
            resolveTapIntent(isMyDeviceActive: isActive, gamePhase: gamePhase),
            GestureIntent.none,
          );
        });
      }
    }
  });
}
