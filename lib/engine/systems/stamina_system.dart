import 'package:smash_bros/engine/entities/player.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';
import 'package:smash_bros/engine/systems/shot_type.dart';

/// Owns every rule that changes a player's stamina (M1-011).
///
/// ## Contract
///
/// This is the *single* place allowed to mutate [Player.stamina]; the [Player]
/// entity never touches the field itself. Every method is a stateless static —
/// the system holds no state of its own and draws no randomness (the seeded
/// `GameRandom` is untouched), so its effects are a pure function of the
/// player's current stamina and the action taken.
///
/// ## Tick order
///
/// Within a simulation tick the Simulation (a later PR) calls, in this order:
/// [chargeShot] / [chargeJump] when the corresponding action is committed, then
/// [tick] once with whether the player moved this tick. [effortMultiplier] is a
/// read-only query the Simulation folds into movement speed and into the
/// `ShotModifiers.powerMultiplier` of a swing; it never mutates.
abstract final class StaminaSystem {
  /// Applies the per-tick stamina change for one player.
  ///
  /// When [moved] is true the player spent effort this tick and drains
  /// [Tunables.staminaDrainMove]. Otherwise, if the player [Player.isGrounded],
  /// they regenerate [Tunables.staminaRegen] — there is **no** regen mid-air
  /// (you cannot catch your breath while leaping). The result is clamped to
  /// `[0, kStaminaMax]`.
  ///
  /// Stun does **not** block regeneration: recovering stamina while stunned is
  /// intended, so a stunned-but-idle grounded player still regens.
  static void tick(Player player, {required bool moved}) {
    if (moved) {
      player.stamina = player.stamina - Tunables.staminaDrainMove;
    } else if (player.isGrounded) {
      player.stamina = player.stamina + Tunables.staminaRegen;
    }
    player.stamina = player.stamina.clamp(Fix.zero, Tunables.staminaMax);
  }

  /// Drains the stamina cost of charging a shot of [type], clamped at 0.
  ///
  /// Costs: normal = [Tunables.staminaDrainNormal], smash =
  /// [Tunables.staminaDrainSmash], drop = [Tunables.staminaDrainNormal] (a drop
  /// is the same effort as a normal stroke), toss = 0 (a serve toss is gentle).
  static void chargeShot(Player player, ShotType type) {
    final cost = switch (type) {
      ShotType.normal => Tunables.staminaDrainNormal,
      ShotType.smash => Tunables.staminaDrainSmash,
      ShotType.drop => Tunables.staminaDrainNormal,
      ShotType.toss => Fix.zero,
    };
    player.stamina = (player.stamina - cost).clamp(
      Fix.zero,
      Tunables.staminaMax,
    );
  }

  /// Drains the stamina cost of a jump ([Tunables.staminaDrainJump]), clamped
  /// at 0.
  static void chargeJump(Player player) {
    player.stamina = (player.stamina - Tunables.staminaDrainJump).clamp(
      Fix.zero,
      Tunables.staminaMax,
    );
  }

  /// The low-stamina effort debuff (M1-011): a multiplier in
  /// `[kStaminaMinMultiplier, 1.0]`.
  ///
  /// Returns 1.0 while stamina is at or above [Tunables.staminaDebuffThreshold]
  /// (including exactly at the threshold). Below it the multiplier interpolates
  /// linearly from 1.0 at the threshold down to [Tunables.staminaMinMultiplier]
  /// at 0 stamina:
  ///
  /// ```text
  ///   t = stamina / threshold                       (0 .. 1)
  ///   m = min + (1 - min) * t
  /// ```
  ///
  /// Pure: reads [Player.stamina] and mutates nothing. The Simulation scales
  /// movement speed by this and composes it into a swing's power multiplier.
  static Fix effortMultiplier(Player player) {
    if (player.stamina >= Tunables.staminaDebuffThreshold) {
      return Fix.one;
    }
    final t = player.stamina / Tunables.staminaDebuffThreshold;
    return Tunables.staminaMinMultiplier +
        (Fix.one - Tunables.staminaMinMultiplier) * t;
  }
}
