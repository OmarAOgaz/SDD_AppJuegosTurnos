import 'package:flutter/material.dart';
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

  group('shouldFireTurnStartCue', () {
    const keyA = TurnStartCueKey(
      activePlayerId: 'p1',
      turnStartedAtMs: 1000,
    );
    const keyB = TurnStartCueKey(
      activePlayerId: 'p1',
      turnStartedAtMs: 2000,
    );

    test('fires on rising edge with current key and no prior fire', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: false,
          isMyDeviceActive: true,
          lastFired: null,
          current: keyA,
        ),
        isTrue,
      );
    });

    test('does not fire when device is not active', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: false,
          isMyDeviceActive: false,
          lastFired: null,
          current: keyA,
        ),
        isFalse,
      );
    });

    test('does not fire when current key is null', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: false,
          isMyDeviceActive: true,
          lastFired: null,
          current: null,
        ),
        isFalse,
      );
    });

    test('same-key dedupe skips re-fire while already active (resync)', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: true,
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyA,
        ),
        isFalse,
      );
    });

    test('same-key dedupe skips rising edge after already cued', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: false,
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyA,
        ),
        isFalse,
      );
    });

    test('new key re-fires on rising edge after inactivity', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: false,
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyB,
        ),
        isTrue,
      );
    });

    test('already active with new key does not fire without rising edge', () {
      expect(
        shouldFireTurnStartCue(
          wasActive: true,
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyB,
        ),
        isFalse,
      );
    });
  });

  group('resolveInvalidTapMarkColor', () {
    test('always red regardless of local seat color', () {
      expect(resolveInvalidTapMarkColor('color_1'), Colors.red);
      expect(resolveInvalidTapMarkColor('color_2'), Colors.red);
      expect(resolveInvalidTapMarkColor('color_3'), Colors.red);
      expect(resolveInvalidTapMarkColor(null), Colors.red);
    });
  });
}
