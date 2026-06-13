import 'package:smash_bros/engine/entities/shuttle.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// Deterministic shuttle trajectory lookahead for the predictive AI tiers.
///
/// ## Contract
///
/// [predictDescentX] integrates a **copy** of the shuttle forward with the
/// exact same semi-implicit Euler step the simulation uses
/// ([Shuttle.integrate]), so the prediction is bit-identical to what the
/// engine will actually compute — no closed-form approximation under
/// quadratic drag is needed (the same reasoning as the M1-035 perfect-block
/// lookahead).
///
/// The ghost simulation deliberately ignores net and ground collision
/// response: it answers "where is the shuttle's x when it next descends to
/// this height", which is exactly the question an AI choosing where to stand
/// needs answered. Callers must clamp the result to their own half (a
/// predicted x beyond the net means "wait at the net").
///
/// Pure and stateless: never touches `GameState.random` or any PRNG, so AI
/// tiers may call it freely without perturbing any random stream.
abstract final class ShuttlePredictor {
  /// Predicts the shuttle's x at the first future tick where it is
  /// **descending** (velocity.y > 0) at or below [targetY], simulating at
  /// most [maxTicks] ticks ahead with [dragCoefficient].
  ///
  /// Reaching the ground plane ([Tunables.groundY]) also terminates the
  /// lookahead (the shuttle cannot descend further), returning the x at the
  /// ground crossing. Returns `null` if neither happens within [maxTicks] —
  /// callers should fall back to tracking the shuttle's current x.
  static Fix? predictDescentX(
    Shuttle shuttle, {
    required Fix dragCoefficient,
    required Fix targetY,
    int maxTicks = 240,
  }) {
    final ghost = shuttle.copy();
    for (var i = 0; i < maxTicks; i++) {
      ghost.integrate(dragCoefficient: dragCoefficient);
      final descending = ghost.velocity.y > Fix.zero;
      if (descending && ghost.position.y >= targetY) {
        return ghost.position.x;
      }
      if (ghost.position.y >= Tunables.groundY) {
        return ghost.position.x;
      }
    }
    return null;
  }
}
