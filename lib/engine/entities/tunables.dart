import 'package:smash_bros/engine/balance/balance_config.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/math/fix.dart';

/// [Fix] mirrors of the gameplay constants the entity layer consumes.
///
/// The raw values in `constants.dart` are plain [double]s (they are also read
/// by the rendering layer and by tools that have no [Fix] dependency). The
/// simulation engine, however, may never mix raw doubles into its math, so we
/// wrap each needed constant exactly once here with [Fix.of] and let entity
/// code reference the wrapped value. This is the single sanctioned
/// double-to-[Fix] boundary for entities — no other engine file should call
/// [Fix.of] on a gameplay constant.
///
/// ## Two kinds of value (M1-032)
///
/// * **Structural** geometry, hitbox sizes, shot **angles**, and scoring stay
///   `static const Fix` — they are fixed by the verified net-clearance math
///   and are never slider-tuned.
/// * **Feel** parameters (gravity, drags, launch/player speeds, stamina
///   drains) are getters that read the active [BalanceConfig] applied via
///   [apply]. They start at [BalanceConfig.defaults] (built straight from the
///   `k*` constants) so behaviour is identical until the game layer loads
///   `assets/data/balance.json` or the debug overlay tunes a value.
///
/// The active config is set **once before a match** and never mutated
/// mid-match, so determinism within a match is preserved (see
/// `BalanceConfig`).
abstract final class Tunables {
  /// The active feel config. Defaults to the shipped values; the game layer
  /// replaces it via [apply] after loading the balance asset, and the debug
  /// tuning overlay replaces it again on each slider change + match restart.
  static BalanceConfig _config = const BalanceConfig.defaults();

  /// The currently active feel config (read by the overlay to seed sliders).
  static BalanceConfig get config => _config;

  /// Applies [config] as the active feel config.
  ///
  /// Call **before** constructing the `Simulation` for a match (or restart the
  /// match immediately after) — changing it mid-match would alter physics
  /// between ticks and is not supported. Named as a verb (not a setter)
  /// because at call sites "apply this balance" reads as an event.
  // ignore: use_setters_to_change_properties
  static void apply(BalanceConfig config) => _config = config;

  /// Restores the shipped defaults. Tests that mutate the config via [apply]
  /// must call this in tear-down to avoid leaking config into other tests.
  static void resetToDefaults() => _config = const BalanceConfig.defaults();
  // -- Court ----------------------------------------------------------------

  /// The x coordinate of the net (centre of the court).
  static const Fix netX = Fix.of(kNetX);

  /// The y coordinate of the top of the net. Smaller y is higher on screen,
  /// so this sits *above* the ground.
  static const Fix netTopY = Fix.of(kNetTopY);

  /// The y coordinate of the ground plane (player feet rest here).
  static const Fix groundY = Fix.of(kGroundY);

  /// Height of the net-cord (tape) band below the net top.
  static const Fix netTapeHeight = Fix.of(kNetTapeHeight);

  /// The y coordinate of the bottom of the net-cord band. A net-plane crossing
  /// at or above this y (but at/below [netTopY]) is a net-cord hit.
  static const Fix netTapeBottomY = Fix.of(kNetTopY + kNetTapeHeight);

  /// The leftmost playable x (outer court boundary).
  static const Fix courtLeftBound = Fix.of(kCourtLeftBound);

  /// The rightmost playable x (outer court boundary).
  static const Fix courtRightBound = Fix.of(kCourtRightBound);

  /// The short-service line on the left half of the court.
  static const Fix shortServeLineLeft = Fix.of(kShortServeLineLeft);

  /// The short-service line on the right half of the court.
  static const Fix shortServeLineRight = Fix.of(kShortServeLineRight);

  // -- Player ---------------------------------------------------------------

  /// Horizontal movement speed in game units per tick (feel — tunable).
  static Fix get playerSpeed => Fix.of(_config.playerSpeed);

  /// Player hitbox width in game units.
  static const Fix playerHitboxWidth = Fix.of(kPlayerHitboxWidth);

  /// Player hitbox height in game units.
  static const Fix playerHitboxHeight = Fix.of(kPlayerHitboxHeight);

  /// Half the player hitbox width — the clamp inset from a boundary.
  static const Fix playerHalfWidth = Fix.of(kPlayerHitboxWidth / 2);

  /// Peak height of a jump above the ground, in game units.
  static const Fix playerJumpHeight = Fix.of(kPlayerJumpHeight);

  /// Extra reach the racquet adds to the player hitbox on the facing side
  /// (and upward), in game units.
  static const Fix racquetReach = Fix.of(kRacquetReach);

  /// Speed multiplier applied to an airborne smash (the jump smash) — feel.
  static Fix get jumpSmashBonus => Fix.of(_config.jumpSmashBonus);

  /// Horizontal offset from the server's centre toward the net at which the
  /// shuttle is placed for a serve.
  static const Fix serveShuttleOffsetX = Fix.of(kServeShuttleOffsetX);

  /// Height above the ground at which the serve shuttle is placed.
  static const Fix serveShuttleHeight = Fix.of(kServeShuttleHeight);

  /// Maximum (and starting) stamina.
  static const Fix staminaMax = Fix.of(kStaminaMax);

  /// Stamina drained by a normal (or drop) shot (feel — tunable).
  static Fix get staminaDrainNormal => Fix.of(_config.staminaDrainNormal);

  /// Stamina drained by a smash (feel — tunable).
  static Fix get staminaDrainSmash => Fix.of(_config.staminaDrainSmash);

  /// Stamina drained by a jump (feel — tunable).
  static Fix get staminaDrainJump => Fix.of(_config.staminaDrainJump);

  /// Stamina drained per tick of movement (feel — tunable).
  static Fix get staminaDrainMove => Fix.of(_config.staminaDrainMove);

  /// Stamina regained per tick while idle and grounded (feel — tunable).
  static Fix get staminaRegen => Fix.of(_config.staminaRegen);

  /// Stamina level below which the low-stamina effort debuff applies.
  static const Fix staminaDebuffThreshold = Fix.of(kStaminaDebuffThreshold);

  /// Minimum effort multiplier when stamina is fully depleted.
  static const Fix staminaMinMultiplier = Fix.of(kStaminaMinMultiplier);

  /// Power multiplier for the weak pop-up return of an imperfectly timed
  /// smash block (M1-035).
  static const Fix imperfectBlockPower = Fix.of(kImperfectBlockPowerMultiplier);

  // -- Shuttle (feel — tunable) ---------------------------------------------

  /// Per-tick downward gravity applied to the shuttle's velocity (+y).
  static Fix get shuttleGravity => Fix.of(_config.shuttleGravity);

  /// Maximum shuttle speed in game units per tick (stability safeguard).
  static Fix get shuttleMaxVelocity => Fix.of(_config.shuttleMaxVelocity);

  /// Velocity-scaling factor applied when the shuttle clips the net cord.
  static Fix get netCordDamping => Fix.of(_config.netCordDamping);

  /// Quadratic-drag coefficient for normal shuttle flight (the rally default).
  static Fix get shuttleDragCoefficient =>
      Fix.of(_config.shuttleDragCoefficient);

  /// Quadratic-drag coefficient for drop shots (higher, bleeds speed faster).
  static Fix get shuttleDropShotDrag => Fix.of(_config.shuttleDropShotDrag);

  // -- Shots ----------------------------------------------------------------

  /// Launch speed of a normal clear/drive shot, in game units per tick (feel).
  static Fix get normalShotSpeed => Fix.of(_config.normalShotSpeed);

  /// Minimum launch angle of a normal shot, in radians.
  static const Fix normalShotAngleMin = Fix.of(kNormalShotAngleMin);

  /// Maximum launch angle of a normal shot, in radians.
  static const Fix normalShotAngleMax = Fix.of(kNormalShotAngleMax);

  /// Launch speed of a smash, in game units per tick (feel — tunable).
  static Fix get smashSpeed => Fix.of(_config.smashSpeed);

  /// Minimum launch angle of a smash, in radians.
  static const Fix smashAngleMin = Fix.of(kSmashAngleMin);

  /// Maximum launch angle of a smash, in radians.
  static const Fix smashAngleMax = Fix.of(kSmashAngleMax);

  /// Launch speed of a drop shot, in game units per tick (feel — tunable).
  static Fix get dropShotSpeed => Fix.of(_config.dropShotSpeed);

  /// Launch angle of a drop shot, in radians (fixed, no spread).
  static const Fix dropShotAngle = Fix.of(kDropShotAngle);

  /// Minimum launch speed of a serve toss (tap-release), per tick (feel).
  static Fix get tossSpeedMin => Fix.of(_config.tossSpeedMin);

  /// Maximum launch speed of a serve toss (full charge), per tick (feel).
  static Fix get tossSpeedMax => Fix.of(_config.tossSpeedMax);

  /// Launch angle of a serve toss, in radians (fixed, no spread).
  static const Fix tossAngle = Fix.of(kTossAngle);
}
