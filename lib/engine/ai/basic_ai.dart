import 'package:smash_bros/engine/ai/ai_difficulty.dart';
import 'package:smash_bros/engine/ai/rule_based_ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/sim/game_state.dart';

/// Shot-mix thresholds for `GameRandom.nextInt` draws in [0, 100):
///   0..69  → normal shot (70 %)
///   70..89 → smash      (20 %)
///   90..99 → drop shot  (10 %)
const int _kShotMixNormalMax = 70; // [0, 70)  → normal
const int _kShotMixSmashMax = 90; // [70, 90) → smash

/// The easy-tier rule-based opponent (M1-028).
///
/// The original launch AI, now expressed as the baseline [RuleBasedAi] tier
/// (see the base class for the shared serve/rally skeleton). What makes it
/// "easy":
///
/// * **15-tick reaction delay** (0.25 s) after the shuttle crosses the net.
/// * **No prediction** — it chases the shuttle's *current* x and is therefore
///   always late to fast shots; while the shuttle is on the opponent's side
///   it walks home.
/// * **Passive 70/20/10 shot mix** (normal/smash/drop) drawn from its
///   private PRNG.
///
/// A smash is always emitted as `jump | smash` (M1-036: jump and smash are
/// one action game-wide). The tick order starts the jump before the swing
/// resolves, so the engine registers an airborne smash with the jump-smash
/// bonus.
final class BasicAI extends RuleBasedAi {
  /// Creates a [BasicAI] for [side] using [seed] to seed its private PRNG.
  BasicAI({required super.side, required super.seed});

  @override
  AiDifficulty get difficulty => AiDifficulty.easy;

  @override
  int get serveTossDelayTicks => 45; // ≈ 0.75 s pause before serving.

  @override
  int get reactionDelayTicks => 15; // 0.25 s — deliberately human-slow.

  @override
  double get movementDeadZone => 12;

  @override
  int get swingCooldownTicks => 12;

  /// Chases the shuttle's current x while it is on our side; walks home
  /// while it is on the opponent's side.
  @override
  double targetX(GameState state, CourtSide shuttleSide) {
    if (shuttleSide == side) {
      // Chase the shuttle's raw x — movement clamping keeps us on our half.
      return state.shuttle.position.x.toDouble();
    }
    return homeX;
  }

  /// Chooses shot bits from the 70/20/10 distribution.
  ///
  /// A smash draw returns `jump | smash` — see the class docs for the
  /// tick-order argument.
  @override
  int chooseShotBit(GameState state) {
    final roll = random.nextInt(100);
    if (roll < _kShotMixNormalMax) return InputAction.normalShot;
    if (roll < _kShotMixSmashMax) return InputAction.jump | InputAction.smash;
    return InputAction.dropShot;
  }
}
