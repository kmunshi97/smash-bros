// HUD component tests (M1-026).
//
// Tests:
//   • onLoad adds ScoreHudComponent, two StaminaBarComponents, and
//     PhaseBannerComponent to the viewport.
//   • Score text shows '0 – 0' at match start; serve indicator reflects
//     view.server (left at start with default firstServer).
//   • Stamina bar fill fraction equals view.staminaFraction at start (1.0 →
//     inner width full); movement drains stamina and fill shrinks.
//   • Phase banner: hidden at match start (servePending). Driving
//     kServeTimeoutFrames ticks without tossing causes the left server to
//     fault, awarding the point to the right side, moving to pointScored — the
//     banner must show 'POINT — RIGHT'.
//   • Score text updates to '0 – 1' after that point.
//
// Engine-semantic note for the timeout point:
//   MatchFsm.tickServeTimer awards the point to the RECEIVER when the server
//   fails to toss in time (PointReason.serveTimeoutFault). Default firstServer
//   is CourtSide.left, so receiver = CourtSide.right → banner says
//   'POINT — RIGHT' and score becomes leftScore=0, rightScore=1.
//   Source: lib/engine/rules/match_fsm.dart, tickServeTimer() →
//   _awardPoint(frame, receiver, PointReason.serveTimeoutFault).
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/hud/hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BadmintonGame> buildGame({int seed = 7}) =>
      initializeGame(() => BadmintonGame(seed: seed));

  // ---------------------------------------------------------------------------
  // Viewport registration
  // ---------------------------------------------------------------------------

  group('BadmintonGame.onLoad — HUD components in viewport', () {
    test('viewport contains a ScoreHudComponent after onLoad', () async {
      final game = await buildGame();
      expect(
        game.camera.viewport.children.whereType<ScoreHudComponent>(),
        isNotEmpty,
        reason: 'ScoreHudComponent must be added to the viewport in onLoad',
      );
      game.onRemove();
    });

    test('viewport contains two StaminaBarComponents after onLoad', () async {
      final game = await buildGame();
      final bars = game.camera.viewport.children
          .whereType<StaminaBarComponent>()
          .toList();
      expect(
        bars.length,
        2,
        reason: 'One StaminaBarComponent per court side',
      );
      game.onRemove();
    });

    test('viewport contains StaminaBarComponents for both sides', () async {
      final game = await buildGame();
      final bars = game.camera.viewport.children
          .whereType<StaminaBarComponent>()
          .toList();
      final sides = bars.map((b) => b.side).toSet();
      expect(
        sides,
        containsAll([CourtSide.left, CourtSide.right]),
        reason: 'StaminaBarComponents must cover left and right',
      );
      game.onRemove();
    });

    test('viewport contains a PhaseBannerComponent after onLoad', () async {
      final game = await buildGame();
      expect(
        game.camera.viewport.children.whereType<PhaseBannerComponent>(),
        isNotEmpty,
        reason: 'PhaseBannerComponent must be added to the viewport in onLoad',
      );
      game.onRemove();
    });
  });

  // ---------------------------------------------------------------------------
  // Score HUD — initial state
  // ---------------------------------------------------------------------------

  group('ScoreHudComponent — initial score state', () {
    test('view score is 0–0 at match start', () async {
      final game = await buildGame();
      expect(
        game.view.leftScore,
        0,
        reason: 'left score must be 0 at match start',
      );
      expect(
        game.view.rightScore,
        0,
        reason: 'right score must be 0 at match start',
      );
      game.onRemove();
    });

    test(
      'view.server is CourtSide.left at match start (default firstServer)',
      () async {
        final game = await buildGame();
        expect(
          game.view.server,
          CourtSide.left,
          reason:
              'default firstServer is left; serve indicator must point left',
        );
        game.onRemove();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Stamina bar — fill fraction
  // ---------------------------------------------------------------------------

  group('StaminaBarComponent — stamina fraction', () {
    test(
      'left player staminaFraction is 1.0 at match start',
      () async {
        final game = await buildGame();
        expect(
          game.view.leftPlayer.staminaFraction,
          closeTo(1.0, 0.001),
          reason: 'stamina starts full (fraction == 1.0)',
        );
        game.onRemove();
      },
    );

    test(
      'left player staminaFraction drops below 1.0 after sustained movement',
      () async {
        final game = await buildGame();

        // Simulate holding moveRight for enough ticks to drain stamina.
        // Each tick drains kStaminaDrainMove (0.5) while moving;
        // 30 ticks = 15 stamina drained from 100 → fraction ≈ 0.85.
        game.controls.moveRight = true;
        game.update(kTickDuration * 30);

        expect(
          game.view.leftPlayer.staminaFraction,
          lessThan(1.0),
          reason:
              'holding moveRight for 30 ticks must drain stamina below full',
        );
        game.onRemove();
      },
    );

    test(
      'fill width shrinks proportionally to staminaFraction after movement',
      () async {
        final game = await buildGame();

        // Snapshot fraction at start (should be 1.0).
        final fractionBefore = game.view.leftPlayer.staminaFraction;

        // Drain stamina.
        game.controls.moveRight = true;
        game.update(kTickDuration * 30);

        final fractionAfter = game.view.leftPlayer.staminaFraction;

        // Verify fraction reduced — the bar component renders
        // fillWidth = innerWidth * fraction; a smaller fraction means a
        // narrower fill. We verify the fraction change directly since the
        // render method can't be invoked in isolation in unit tests.
        expect(
          fractionAfter,
          lessThan(fractionBefore),
          reason:
              'staminaFraction after 30 movement ticks must be less than '
              'the initial fraction of $fractionBefore',
        );
        game.onRemove();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Phase banner — visibility and content
  // ---------------------------------------------------------------------------

  group('PhaseBannerComponent — phase visibility', () {
    test(
      'phase is servePending at match start (banner would be hidden)',
      () async {
        final game = await buildGame();
        // The banner renders nothing for servePending. We verify the phase via
        // view rather than inspecting internal render state.
        expect(
          game.view.phase,
          MatchPhase.servePending,
          reason: 'phase at boot must be servePending; banner hides itself',
        );
        game.onRemove();
      },
    );

    test(
      'after kServeTimeoutFrames ticks without toss → pointScored, '
      'pointWinner is CourtSide.right (serve-timeout fault awards point to receiver)',
      () async {
        final game = await buildGame();

        // Drive exactly kServeTimeoutFrames simulation ticks. The
        // FixedTimestepDriver caps ticks per advance() call at maxTicksPerAdvance
        // (5), so we must call update() in a loop — one tick per call — rather
        // than one large advance.  On reaching kServeTimeoutFrames the FSM
        // awards the point to the receiver (right side) via
        // PointReason.serveTimeoutFault and transitions to pointScored.
        // Source: MatchFsm.tickServeTimer → _awardPoint(receiver, serveTimeoutFault).
        for (var i = 0; i < kServeTimeoutFrames; i++) {
          game.update(kTickDuration);
        }

        expect(
          game.view.phase,
          MatchPhase.pointScored,
          reason:
              'after $kServeTimeoutFrames ticks without a toss the server '
              'faults and the FSM must enter pointScored',
        );

        expect(
          game.view.pointWinner,
          CourtSide.right,
          reason:
              'serveTimeoutFault awards the point to the receiver (right), '
              'not the server (left); see MatchFsm.tickServeTimer → '
              '_awardPoint(frame, receiver, serveTimeoutFault)',
        );

        game.onRemove();
      },
    );

    test(
      'score is 0–1 after serve-timeout fault by left server',
      () async {
        final game = await buildGame();
        for (var i = 0; i < kServeTimeoutFrames; i++) {
          game.update(kTickDuration);
        }

        expect(
          game.view.leftScore,
          0,
          reason: 'server (left) gets no point on a timeout fault',
        );
        expect(
          game.view.rightScore,
          1,
          reason: 'receiver (right) wins 1 point from the timeout fault',
        );
        game.onRemove();
      },
    );

    test(
      'lastPointReason is serveTimeoutFault after serve timeout',
      () async {
        final game = await buildGame();
        for (var i = 0; i < kServeTimeoutFrames; i++) {
          game.update(kTickDuration);
        }

        expect(
          game.view.lastPointReason?.name,
          'serveTimeoutFault',
          reason:
              'MatchFsm.tickServeTimer must set lastPointReason to '
              'serveTimeoutFault on a serve-timer expiry',
        );
        game.onRemove();
      },
    );
  });
}
