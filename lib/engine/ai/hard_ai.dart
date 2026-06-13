import 'package:meta/meta.dart';
import 'package:smash_bros/engine/ai/ai_difficulty.dart';
import 'package:smash_bros/engine/ai/rule_based_ai.dart';
import 'package:smash_bros/engine/ai/shuttle_predictor.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/sim/game_state.dart';

/// Shot-mix thresholds for `GameRandom.nextInt` draws in [0, 100):
///   0..49  → normal shot (50 %)
///   50..84 → smash      (35 %)
///   85..99 → drop shot  (15 %)
const int _kShotMixNormalMax = 50; // [0, 50)  → normal
const int _kShotMixSmashMax = 85; // [50, 85) → smash

/// The y coordinate at which the predictive tiers want to meet the
/// descending shuttle: 40 units **above the net tape** ([kNetTopY]), inside
/// the standing reach box (whose top is hitbox top − racquet reach). Meeting
/// the shuttle this high keeps a legal downward smash on the table — contact
/// below the tape can never clear the net.
const double _kInterceptY = kNetTopY - 40;

/// Required shuttle height above the net tape before a smash is considered.
const double _kSmashTapeClearance = 30;

/// Approximate drop per horizontal unit of a max-angle smash (tan 15° plus
/// gravity-curvature headroom). A smash is only safe when
/// `distanceToNet * this <= height above the tape`.
const double _kSmashDropPerUnit = 0.35;

/// The hard-tier opponent: prediction over reaction.
///
/// Shares the [RuleBasedAi] serve/rally skeleton with [AiDifficulty.easy]'s
/// `BasicAI`; what makes it "hard":
///
/// * **8-tick reaction delay** — roughly half the easy tier's.
/// * **Trajectory prediction**: as soon as the *opponent* has hit the
///   shuttle, it asks [ShuttlePredictor] where the shuttle will descend to
///   chest height and walks there — often arriving before the shuttle
///   crosses the net, instead of chasing its current position.
/// * **Aggressive 50/35/15 shot mix** (normal/smash/drop).
///
/// A smash is always emitted as `jump | smash` (M1-036), inheriting the
/// jump-smash bonus through the tick order exactly like the easy tier.
///
/// Deliberately non-final: `ChallengingAI` extends it, keeping the
/// positioning logic single-sourced and overriding only the tempo knobs and
/// shot selection.
base class HardAI extends RuleBasedAi {
  /// Creates a [HardAI] for [side] using [seed] to seed its private PRNG.
  HardAI({required super.side, required super.seed});

  @override
  AiDifficulty get difficulty => AiDifficulty.hard;

  @override
  int get serveTossDelayTicks => 30; // ≈ 0.5 s — serves with less dawdling.

  @override
  int get reactionDelayTicks => 8;

  @override
  double get movementDeadZone => 8;

  @override
  int get swingCooldownTicks => 12;

  /// Walks to the predicted descent x of an inbound shuttle; walks home
  /// while our own shot is outbound.
  @override
  double targetX(GameState state, CourtSide shuttleSide) {
    // We hit last: the shuttle is outbound (or we are locked out anyway) —
    // return home for the reply instead of chasing our own shot to the net.
    if (state.rally.lastHitter == side) {
      return homeX;
    }
    return predictedInterceptX(state);
  }

  @override
  int chooseShotBit(GameState state) {
    final roll = random.nextInt(100);
    if (roll < _kShotMixNormalMax) return InputAction.normalShot;
    if (roll < _kShotMixSmashMax && smashClearsNet(state)) {
      return InputAction.jump | InputAction.smash;
    }
    if (roll < _kShotMixSmashMax) {
      // Smash rolled but the geometry says it would hit the tape or land on
      // our own side — downgrade to a safe clear.
      return InputAction.normalShot;
    }
    return InputAction.dropShot;
  }

  /// Whether a downward smash from the shuttle's current position can clear
  /// the net.
  ///
  /// Smashes launch 10–15° downward ([kSmashAngleMin]/[kSmashAngleMax]): the
  /// contact point must sit [_kSmashTapeClearance] above the net tape, and
  /// the drop accumulated over the horizontal run to the net
  /// ([_kSmashDropPerUnit] per unit, which over-estimates tan 15° plus
  /// gravity) must fit inside that height. Contact below the tape can never
  /// clear, no matter the distance.
  @protected
  bool smashClearsNet(GameState state) {
    final shuttle = state.shuttle.position;
    final heightAboveTape = kNetTopY - shuttle.y.toDouble();
    if (heightAboveTape < _kSmashTapeClearance) return false;
    final distanceToNet = (shuttle.x.toDouble() - kNetX).abs();
    return distanceToNet * _kSmashDropPerUnit <= heightAboveTape;
  }

  /// Where the shuttle will descend to chest height, clamped to our half.
  ///
  /// Falls back to the shuttle's current x when the lookahead finds no
  /// descent within its horizon (e.g. a fresh, steep clear still rising).
  /// Shared with `ChallengingAI`, which differs in reaction speed and shot
  /// selection rather than positioning.
  double predictedInterceptX(GameState state) {
    final predicted = ShuttlePredictor.predictDescentX(
      state.shuttle,
      dragCoefficient: state.rally.activeDragCoefficient,
      targetY: const Fix.of(_kInterceptY),
    );
    final x = predicted ?? state.shuttle.position.x;
    // A prediction beyond the net means "wait at the net" — clamp to our
    // half exactly like the movement system will.
    return state.court
        .clampToSide(x, side, Tunables.playerHalfWidth)
        .toDouble();
  }
}
