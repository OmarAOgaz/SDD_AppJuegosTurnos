import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/turn_engine.dart';
import 'package:turnos_juegos/core/domain/turn_feedback.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/turn_state.dart';

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

    test('inGame, active device, normal phase stays literal black (no tint)',
        () {
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

    test('non-active device never flashes or fixes even at warning/exceeded',
        () {
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

    test('fires when acting with current key and no prior fire', () {
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: null,
          current: keyA,
        ),
        isTrue,
      );
    });

    test('does not fire when device is not acting', () {
      expect(
        shouldFireTurnStartCue(
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
          isMyDeviceActive: true,
          lastFired: null,
          current: null,
        ),
        isFalse,
      );
    });

    test('same-key dedupe skips re-fire while already acting (resync)', () {
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyA,
        ),
        isFalse,
      );
    });

    test('already acting with new key fires (own to proxied, no inactive gap)',
        () {
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyB,
        ),
        isTrue,
      );
    });

    test('returnRestore does not fire even when the cue key changes', () {
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyB,
          activationSource: TurnActivationSource.returnRestore,
        ),
        isFalse,
      );
    });

    test('pass activationSource still fires on a new key', () {
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: keyA,
          current: keyB,
          activationSource: TurnActivationSource.pass,
        ),
        isTrue,
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

  group('resolveSwipeIntent', () {
    SwipeIntent eligible({
      double dx = -returnSwipeMinDistance,
      double velocityDx = 0,
      GameRoomPhase gamePhase = GameRoomPhase.inGame,
      bool isDeviceActing = true,
      bool hasReturnableLastPass = true,
      bool panelOpen = false,
      bool cueVisible = false,
      bool hasPendingReturnRequest = false,
    }) {
      return resolveSwipeIntent(
        dx: dx,
        velocityDx: velocityDx,
        gamePhase: gamePhase,
        isDeviceActing: isDeviceActing,
        hasReturnableLastPass: hasReturnableLastPass,
        panelOpen: panelOpen,
        cueVisible: cueVisible,
        hasPendingReturnRequest: hasPendingReturnRequest,
      );
    }

    test('distance at 64px left requests return when eligible', () {
      expect(eligible(dx: -64), SwipeIntent.requestReturn);
    });

    test('distance just under 64px with no velocity is none (tap replay)', () {
      expect(eligible(dx: -63), SwipeIntent.none);
    });

    test('velocity at 300px/s left requests return even with small dx', () {
      expect(
        eligible(dx: -10, velocityDx: -returnSwipeMinVelocity),
        SwipeIntent.requestReturn,
      );
    });

    test('velocity just under 300px/s with small dx is none', () {
      expect(eligible(dx: -10, velocityDx: -299), SwipeIntent.none);
    });

    test('right swipe is none', () {
      expect(eligible(dx: 80, velocityDx: 400), SwipeIntent.none);
    });

    test('first seat of the round (no last-pass) is blocked', () {
      expect(eligible(hasReturnableLastPass: false), SwipeIntent.blocked);
    });

    test('fixed-order wrap lastPass is green request', () {
      const lastPass = LastPassSnapshot(
        playerId: 'p2',
        elapsedMs: 20000,
        round: 1,
        durationSeconds: 60,
        turnCountDelta: 1,
        turnMsDelta: 20000,
        exceededTurnCountDelta: 0,
        exceededMsDelta: 0,
      );
      expect(
        TurnEngine.hasReturnableLastPass(lastPass, 2, false),
        isTrue,
      );
      expect(
        eligible(
          hasReturnableLastPass: TurnEngine.hasReturnableLastPass(
            lastPass,
            2,
            false,
          ),
        ),
        SwipeIntent.requestReturn,
      );
    });

    test('variable-order first-of-round helper is false so swipe is blocked',
        () {
      const lastPass = LastPassSnapshot(
        playerId: 'p2',
        elapsedMs: 20000,
        round: 1,
        durationSeconds: 60,
        turnCountDelta: 1,
        turnMsDelta: 20000,
        exceededTurnCountDelta: 0,
        exceededMsDelta: 0,
      );
      expect(
        TurnEngine.hasReturnableLastPass(lastPass, 2, true),
        isFalse,
      );
      expect(
        eligible(
          hasReturnableLastPass: TurnEngine.hasReturnableLastPass(
            lastPass,
            2,
            true,
          ),
        ),
        SwipeIntent.blocked,
      );
    });

    test('non-acting sender is blocked', () {
      expect(eligible(isDeviceActing: false), SwipeIntent.blocked);
    });

    test('cue visible is silent none (occupancy, not blocked)', () {
      expect(eligible(cueVisible: true), SwipeIntent.none);
    });

    test('panel open is silent none (occupancy, not blocked)', () {
      expect(eligible(panelOpen: true), SwipeIntent.none);
    });

    test('already pending is blocked', () {
      expect(eligible(hasPendingReturnRequest: true), SwipeIntent.blocked);
    });

    test('outside inGame is none even with a qualifying swipe', () {
      for (final phase in [
        GameRoomPhase.lobby,
        GameRoomPhase.betweenRounds,
        GameRoomPhase.ended,
      ]) {
        expect(eligible(gamePhase: phase), SwipeIntent.none);
      }
    });
  });

  group('resolveReturnRequestRole', () {
    const pending = PendingReturnRequest(
      requestId: 'bruno@1000',
      requesterPlayerId: 'bruno',
      previousPlayerId: 'ana',
      requestedAtMs: 1000,
      expiresAtMs: 11000,
    );

    test('no pending is none', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'bruno',
          hostPlayerId: 'host',
          actingSeatId: 'bruno',
          previousConnected: true,
          pending: null,
        ),
        ReturnRequestRole.none,
      );
    });

    test('previous connected seat answers', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'ana',
          hostPlayerId: 'host',
          actingSeatId: null,
          previousConnected: true,
          pending: pending,
        ),
        ReturnRequestRole.answer,
      );
    });

    test('requester acting seat waits', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'bruno',
          hostPlayerId: 'host',
          actingSeatId: 'bruno',
          previousConnected: true,
          pending: pending,
        ),
        ReturnRequestRole.waiting,
      );
    });

    test('bystander is none', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'carla',
          hostPlayerId: 'host',
          actingSeatId: null,
          previousConnected: true,
          pending: pending,
        ),
        ReturnRequestRole.none,
      );
    });

    test('host dual-role answers once (not waiting) when previous disconnected',
        () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'host',
          hostPlayerId: 'host',
          actingSeatId: 'bruno',
          previousConnected: false,
          pending: pending,
        ),
        ReturnRequestRole.answer,
      );
    });

    test('host acting-as requester waits when previous is connected', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'host',
          hostPlayerId: 'host',
          actingSeatId: 'bruno',
          previousConnected: true,
          pending: pending,
        ),
        ReturnRequestRole.waiting,
      );
    });

    test('disconnected previous seat itself does not answer', () {
      expect(
        resolveReturnRequestRole(
          localPlayerId: 'ana',
          hostPlayerId: 'host',
          actingSeatId: null,
          previousConnected: false,
          pending: pending,
        ),
        ReturnRequestRole.none,
      );
    });
  });

  group('return-turn cue routes', () {
    const pending = PendingReturnRequest(
      requestId: 'bruno@1000',
      requesterPlayerId: 'bruno',
      previousPlayerId: 'ana',
      requestedAtMs: 1000,
      expiresAtMs: 11000,
    );

    ReturnOutcome outcome(ReturnOutcomeResult result) {
      return ReturnOutcome(
        requestId: pending.requestId,
        result: result,
        requesterPlayerId: pending.requesterPlayerId,
        previousPlayerId: pending.previousPlayerId,
      );
    }

    test('request arrival cues previous, not requester', () {
      expect(
        shouldFireReturnRequestCue(
          pending: pending,
          localPlayerId: 'ana',
          lastFiredRequestId: null,
        ),
        isTrue,
      );
      expect(
        shouldFireReturnRequestCue(
          pending: pending,
          localPlayerId: 'bruno',
          lastFiredRequestId: null,
        ),
        isFalse,
      );
    });

    test('request arrival is deduped by requestId', () {
      expect(
        shouldFireReturnRequestCue(
          pending: pending,
          localPlayerId: 'ana',
          lastFiredRequestId: pending.requestId,
        ),
        isFalse,
      );
    });

    test('accept does not cue restore or outcome on any device', () {
      const restoredKey = TurnStartCueKey(
        activePlayerId: 'ana',
        turnStartedAtMs: 3000,
      );
      expect(
        shouldFireTurnStartCue(
          isMyDeviceActive: true,
          lastFired: null,
          current: restoredKey,
          activationSource: TurnActivationSource.returnRestore,
        ),
        isFalse,
      );
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.accepted),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.accepted),
          actingSeatId: 'ana',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
    });

    test('reject cues requester only', () {
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.rejected),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: null,
        ),
        isTrue,
      );
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.rejected),
          actingSeatId: 'ana',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
    });

    test('timeout cues requester only', () {
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.expired),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: null,
        ),
        isTrue,
      );
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.expired),
          actingSeatId: 'ana',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
    });

    test('host acting-as requester still receives reject/expire cue', () {
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.rejected),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: null,
        ),
        isTrue,
      );
    });

    test('cancel cues nobody', () {
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.cancelled),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.cancelled),
          actingSeatId: 'ana',
          lastFiredOutcomeRequestId: null,
        ),
        isFalse,
      );
    });

    test('outcome cue is deduped by requestId', () {
      expect(
        shouldFireReturnOutcomeCue(
          outcome: outcome(ReturnOutcomeResult.rejected),
          actingSeatId: 'bruno',
          lastFiredOutcomeRequestId: pending.requestId,
        ),
        isFalse,
      );
    });
  });
}
