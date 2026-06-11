import 'dart:math';

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------

/// Fixed simulation rate in ticks per second.
const int kTickRate = 60;

/// Duration of a single simulation tick, in seconds.
const double kTickDuration = 1.0 / kTickRate;

// ---------------------------------------------------------------------------
// Court (game-unit coordinate system)
// ---------------------------------------------------------------------------

/// Court width in game units.
const double kCourtWidth = 1280;

/// Court height in game units.
const double kCourtHeight = 720;

/// X coordinate of the net (court centre line).
const double kNetX = kCourtWidth / 2;

/// Y coordinate of the top of the net (smaller y is higher on screen, so this
/// sits above the ground).
const double kNetTopY = 350;

/// Height of the net-cord band (the tape) below the net top.
///
/// A sweep crossing the net plane within `[kNetTopY, kNetTopY + kNetTapeHeight]`
/// is a tape (net-cord) hit rather than a net-body hit. Above the band is clean
/// passage; below it is a solid net-body hit.
const double kNetTapeHeight = 8;

/// Y coordinate of the ground plane.
const double kGroundY = 600;

/// Leftmost playable x (outer court boundary).
const double kCourtLeftBound = 40;

/// Rightmost playable x (outer court boundary).
const double kCourtRightBound = kCourtWidth - 40;

/// Short-service line on the left half of the court.
const double kShortServeLineLeft = kNetX - 200;

/// Short-service line on the right half of the court.
const double kShortServeLineRight = kNetX + 200;

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

/// Horizontal movement speed in game units per tick.
const double kPlayerSpeed = 6;

/// Y coordinate of the jump apex (the feet's highest point).
const double kPlayerJumpApexY = 380;

/// Peak jump height above the ground, in game units.
const double kPlayerJumpHeight = kGroundY - kPlayerJumpApexY;

/// Duration of a jump arc, in ticks.
const int kPlayerJumpDuration = 40;

/// Player hitbox width in game units.
const double kPlayerHitboxWidth = 48;

/// Player hitbox height in game units.
const double kPlayerHitboxHeight = 80;

/// Starting x of player 1 (left side).
const double kPlayer1StartX = kCourtLeftBound + 120;

/// Starting x of player 2 (right side).
const double kPlayer2StartX = kCourtRightBound - 120;

/// Extra horizontal and vertical reach the racquet adds to the player hitbox
/// on the facing side (and upward), in game units. Models the racquet arm
/// extending the effective contact zone in front of and above the body.
const double kRacquetReach = 40;

/// Speed multiplier applied to a smash hit while the player is airborne — the
/// genre-defining jump smash hits harder than a grounded smash.
const double kJumpSmashBonus = 1.15;

// ---------------------------------------------------------------------------
// Shuttle
// ---------------------------------------------------------------------------

/// Per-tick downward gravity applied to the shuttle (+y).
const double kShuttleGravity = 0.15;

/// Quadratic-drag coefficient for normal flight.
const double kShuttleDragCoefficient = 0.003;

/// Quadratic-drag coefficient for drop shots (higher, bleeds speed faster).
const double kShuttleDropShotDrag = 0.006;

/// Maximum shuttle speed in game units per tick (stability safeguard).
const double kShuttleMaxVelocity = 20;

/// Shuttle collision radius in game units.
const double kShuttleRadius = 6;

/// Velocity-scaling factor applied when the shuttle clips the net cord (tape).
///
/// A net-cord hit damps the shuttle but lets it continue; its velocity is
/// multiplied by this factor.
const double kNetCordDamping = 0.5;

/// Launch speed of a normal clear/drive shot.
const double kNormalShotSpeed = 8;

/// Minimum launch angle of a normal shot, in radians.
const double kNormalShotAngleMin = 35 * (pi / 180);

/// Maximum launch angle of a normal shot, in radians.
const double kNormalShotAngleMax = 45 * (pi / 180);

/// Launch speed of a smash.
const double kSmashSpeed = 16;

/// Minimum launch angle of a smash, in radians.
const double kSmashAngleMin = 10 * (pi / 180);

/// Maximum launch angle of a smash, in radians.
const double kSmashAngleMax = 20 * (pi / 180);

/// Launch speed of a drop shot.
const double kDropShotSpeed = 5;

/// Launch angle of a drop shot, in radians.
const double kDropShotAngle = 25 * (pi / 180);

/// Launch speed of a serve toss.
const double kTossSpeed = 4;

/// Launch angle of a serve toss, in radians.
const double kTossAngle = 75 * (pi / 180);

// ---------------------------------------------------------------------------
// Timing (in frames at 60 fps)
// ---------------------------------------------------------------------------

/// First frame of the perfect-block timing window.
const int kPerfectBlockWindowStart = 6;

/// Last frame of the perfect-block timing window.
const int kPerfectBlockWindowEnd = 12;

/// Number of frames a swing animation occupies.
const int kSwingAnimationFrames = 12;

/// Duration of a stun, in frames.
const int kStunDurationFrames = 60;

/// Upper bound on the block-timing lookahead simulation (M1-035).
///
/// The defender-swing block timing is measured by forward-simulating a clone
/// of the shuttle for at most this many ticks to find its arrival tick. The
/// cost of `StunSystem.evaluateBlockTiming` is therefore bounded at this many
/// `Shuttle.integrate` calls per defender swing.
const int kBlockLookaheadMaxTicks = 30;

/// Frames before a serve times out.
const int kServeTimeoutFrames = 300;

// ---------------------------------------------------------------------------
// Stamina
// ---------------------------------------------------------------------------

/// Maximum (and starting) stamina.
const double kStaminaMax = 100;

/// Stamina drained by a normal shot.
const double kStaminaDrainNormal = 5;

/// Stamina drained by a smash.
const double kStaminaDrainSmash = 15;

/// Stamina drained by a jump.
const double kStaminaDrainJump = 8;

/// Stamina drained per tick of movement.
const double kStaminaDrainMove = 0.5;

/// Stamina regained per tick while idle.
const double kStaminaRegen = 0.3;

/// Stamina level below which the low-stamina debuff applies.
const double kStaminaDebuffThreshold = 30;

/// Minimum action multiplier when stamina is fully depleted.
const double kStaminaMinMultiplier = 0.5;

/// Power multiplier for the weak pop-up return of an imperfectly timed smash
/// block (M1-035). An imperfect block still connects but returns a feeble lob.
const double kImperfectBlockPowerMultiplier = 0.5;

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

/// Points needed to win a game under normal play.
const int kDefaultTargetScore = 11;

/// Score at which deuce rules begin.
const int kDeuceThreshold = 10;

/// Lead required to win during deuce.
const int kDeuceLeadRequired = 2;

/// Hard score cap that ends deuce regardless of lead.
const int kDeuceCap = 15;

/// Ticks spent in the `pointScored` phase before the next serve.
///
/// At 60 ticks/sec this is 1.5 s of "point!" presentation time, giving the HUD
/// room to show the winner of the point before play resets.
const int kPointPauseTicks = 90;

// ---------------------------------------------------------------------------
// Rollback / Netcode (Milestone 3, defined early for buffer sizing)
// ---------------------------------------------------------------------------

/// Maximum number of frames the rollback buffer can rewind.
const int kMaxRollbackFrames = 600;

/// Interval, in frames, between full state snapshots.
const int kSnapshotInterval = 6;
