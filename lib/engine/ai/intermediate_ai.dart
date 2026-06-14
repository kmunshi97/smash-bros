import 'package:smash_bros/engine/ai/ai_difficulty.dart';
import 'package:smash_bros/engine/ai/hard_ai.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/sim/game_state.dart';

/// Shot-mix thresholds for `GameRandom.nextInt` draws in [0, 100):
///   0..64  → normal shot (65 %)
///   65..89 → smash      (25 %)
///   90..99 → drop shot  (10 %)
const int _kShotMixNormalMax = 65; // [0, 65)  → normal
const int _kShotMixSmashMax = 90; // [65, 90) → smash

/// The mid-tier opponent (M2-022): predictive like [HardAI] but slower and
/// less aggressive — the rung between [AiDifficulty.easy] and
/// [AiDifficulty.hard].
///
/// Inherits [HardAI]'s trajectory-prediction positioning (walk to where the
/// shuttle will land) and net-clearance smash gate, but:
///
/// * **12-tick reaction delay** — between easy's 15 and hard's 8.
/// * a slightly looser **movement dead zone** (11) so its positioning is
///   imperfect.
/// * a **calmer 65/25/10 shot mix** (normal/smash/drop) versus hard's 50/35/15.
///
/// Smashes still pass through [HardAI.smashClearsNet], so it never buries one
/// into the tape; jump is only ever emitted alongside smash (M1-036).
final class IntermediateAI extends HardAI {
  /// Creates an [IntermediateAI] for [side] with its private PRNG [seed].
  IntermediateAI({required super.side, required super.seed});

  @override
  AiDifficulty get difficulty => AiDifficulty.intermediate;

  @override
  int get serveTossDelayTicks => 38; // ≈ 0.63 s — a touch slower than hard.

  @override
  int get reactionDelayTicks => 12;

  @override
  double get movementDeadZone => 11;

  @override
  int chooseShotBit(GameState state) {
    final roll = random.nextInt(100);
    if (roll < _kShotMixNormalMax) return InputAction.normalShot;
    if (roll < _kShotMixSmashMax && smashClearsNet(state)) {
      return InputAction.jump | InputAction.smash;
    }
    // Smash rolled but the geometry would hit the tape — play a safe clear.
    if (roll < _kShotMixSmashMax) return InputAction.normalShot;
    return InputAction.dropShot;
  }
}
