import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// The direction a player is facing.
enum Facing {
  /// Facing toward smaller x.
  left,

  /// Facing toward larger x.
  right,
}

/// A player avatar.
///
/// ## Anchor convention (collision-critical)
///
/// A player's position is a single [x] (the horizontal centre of the hitbox)
/// plus a derived [y]. **[y] is the player's feet / ground-contact point.**
/// The hitbox extends *upward* from the feet:
///
/// ```text
///   top    = y - height   (smaller y = higher on screen)
///   bottom = y            (the feet)
///   left   = x - width/2
///   right  = x + width/2
/// ```
///
/// The collision and shot systems rely on this anchor, so it must not drift.
///
/// State is mutable in place and value-semantic; [copy] gives the rollback
/// buffer a deep snapshot. Stamina and stun are stored here but *mutated
/// elsewhere*: the StaminaSystem and StunSystem own those rules in a later
/// PR, so this class never changes [stamina] or [stunTicksRemaining] itself.
final class Player {
  /// Creates a player on [courtSide] whose centre is at [x].
  Player({
    required this.x,
    required this.courtSide,
    this.facing = Facing.right,
    Fix? stamina,
    this.stunTicksRemaining = 0,
    this.jumpTick = _grounded,
  }) : stamina = stamina ?? Tunables.staminaMax;

  /// Sentinel [jumpTick] value meaning "on the ground / not jumping".
  static const int _grounded = -1;

  /// The horizontal centre of the player's hitbox.
  Fix x;

  /// Which half of the net the player owns.
  CourtSide courtSide;

  /// The direction the player is facing.
  Facing facing;

  /// Remaining stamina (mutated by the StaminaSystem, not this class).
  Fix stamina;

  /// Ticks of stun remaining (mutated by the StunSystem, not this class).
  int stunTicksRemaining;

  /// Progress through the current jump in ticks, or [_grounded] (-1) when on
  /// the ground. Runs `0 .. kPlayerJumpDuration`; on reaching the end the
  /// player lands and this resets to [_grounded].
  int jumpTick;

  /// Whether the player is on the ground (not mid-jump).
  bool get isGrounded => jumpTick == _grounded;

  /// Whether the player is currently stunned.
  bool get isStunned => stunTicksRemaining > 0;

  /// The player's feet y.
  ///
  /// Grounded players sit at [kGroundY]. During a jump the feet follow a
  /// parabola peaking [kPlayerJumpHeight] above the ground at the arc
  /// midpoint:
  ///
  /// ```text
  ///   t      = jumpTick / kPlayerJumpDuration   (0 .. 1)
  ///   offset = 4 * h * t * (1 - t)              (0 at t=0,1; h at t=0.5)
  ///   y      = kGroundY - offset                (smaller y = higher)
  /// ```
  Fix get y {
    if (isGrounded) {
      return Tunables.groundY;
    }
    final t = Fix.fromInt(jumpTick) / const Fix.fromInt(kPlayerJumpDuration);
    final offset =
        const Fix.of(4) * Tunables.playerJumpHeight * t * (Fix.one - t);
    return Tunables.groundY - offset;
  }

  /// The left edge of the hitbox (`x - width/2`).
  Fix get hitboxLeft => x - Tunables.playerHalfWidth;

  /// The right edge of the hitbox (`x + width/2`).
  Fix get hitboxRight => x + Tunables.playerHalfWidth;

  /// The top edge of the hitbox (`y - height`; higher on screen than the
  /// feet because y grows downward).
  Fix get hitboxTop => y - Tunables.playerHitboxHeight;

  /// The bottom edge of the hitbox, level with the feet (`y`).
  Fix get hitboxBottom => y;

  /// Begins a jump if able; returns whether one started.
  ///
  /// A no-op (returning `false`) is used rather than an assertion so callers
  /// can rebind inputs freely without guarding every press: the engine simply
  /// ignores jump requests that are not currently legal. A jump is legal only
  /// when the player is [isGrounded] and not [isStunned].
  bool startJump() {
    if (!isGrounded || isStunned) {
      return false;
    }
    jumpTick = 0;
    return true;
  }

  /// Advances the jump arc by one tick, landing after [kPlayerJumpDuration]
  /// ticks. No-op while grounded.
  void tickJump() {
    if (isGrounded) {
      return;
    }
    jumpTick++;
    if (jumpTick >= kPlayerJumpDuration) {
      jumpTick = _grounded;
    }
  }

  /// Moves horizontally by [dx], updating [facing] from the sign of [dx] and
  /// clamping the centre so the hitbox stays inside [court] and on this
  /// player's own half of the net. No-op while [isStunned]; a zero [dx]
  /// leaves [facing] unchanged.
  void moveBy(Fix dx, Court court) {
    if (isStunned) {
      return;
    }
    if (dx > Fix.zero) {
      facing = Facing.right;
    } else if (dx < Fix.zero) {
      facing = Facing.left;
    }
    x = court.clampToSide(x + dx, courtSide, Tunables.playerHalfWidth);
  }

  /// A deep, independent copy for the rollback snapshot buffer.
  Player copy() => Player(
    x: x,
    courtSide: courtSide,
    facing: facing,
    stamina: stamina,
    stunTicksRemaining: stunTicksRemaining,
    jumpTick: jumpTick,
  );
}
