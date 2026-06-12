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

/// Horizontal offset from the server's centre toward the net at which the
/// shuttle is placed for a serve.
const double kServeShuttleOffsetX = 40;

/// Height above the ground at which the serve shuttle is placed.
const double kServeShuttleHeight = 80;

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
///
/// Tuned (M1-032a) from 0.15 to 0.06 so that shots launched from the ground
/// level (y ≈ 520) can rise above the net top (y = 350) in the horizontal
/// distance to the net.  With the original value of 0.15 the gravitational
/// pull was so strong that no realistic launch speed/angle combination could
/// arc a shuttle over the net from the serve or rally start positions.
const double kShuttleGravity = 0.06;

/// Quadratic-drag coefficient for normal flight.
///
/// Tuned (M1-032a) from 0.003 to 0.001.  At the original coefficient the
/// drag bled horizontal speed so fast that even the maximum-velocity shuttle
/// stalled before reaching the far side of the court.  At 0.001 a normal
/// shot from the defensive position (300, 520) clears the net and lands well
/// inside the baseline — see test/engine/balance/.
const double kShuttleDragCoefficient = 0.001;

/// Quadratic-drag coefficient for drop shots (higher, bleeds speed faster).
///
/// Tuned (M1-032a) from 0.006 to 0.002.  The drop shot uses a steep launch
/// angle (kDropShotAngle) to clear the net; the elevated drag then bleeds
/// residual speed, keeping the landing between the net and the short-service
/// line (640–840) — see test/engine/balance/.  Using the same coefficient as
/// normal flight would make drops fly as far as clears, removing their
/// tactical identity.
const double kShuttleDropShotDrag = 0.002;

/// Maximum shuttle speed in game units per tick (stability safeguard).
///
/// Kept at 20.  The fastest legal shot (smash + jump bonus = 16 × 1.15 =
/// 18.4) stays comfortably below this ceiling, so the clamp never fires
/// during normal play.
const double kShuttleMaxVelocity = 20;

/// Shuttle collision radius in game units.
const double kShuttleRadius = 6;

/// Velocity-scaling factor applied when the shuttle clips the net cord (tape).
///
/// A net-cord hit damps the shuttle but lets it continue; its velocity is
/// multiplied by this factor.
const double kNetCordDamping = 0.5;

/// Launch speed of a normal clear/drive shot.
///
/// Unchanged at 8 game-units/tick.  With the new gravity (0.06) and drag
/// (0.001) this speed, combined with the updated angle range, produces
/// trajectories that clear the net from a defensive position (300, 520) and
/// land inside the baseline — see test/engine/balance/.
const double kNormalShotSpeed = 8;

/// Minimum launch angle of a normal shot, in radians.
///
/// Tuned (M1-032a) from 35° to 45°.  The angle range was shifted upward to
/// keep near-net shots (launched from x ≈ 560) from sailing out of bounds
/// under the new lower-gravity/lower-drag physics.  Steeper = shorter range.
/// **Trade-off**: all normal shots arc higher than before, but every shot from
/// any position in the left half clears the net and lands in bounds — the
/// near-net constraint wins over flatness; see the dartdoc in
/// test/engine/balance/shot_balance_test.dart for the full explanation.
const double kNormalShotAngleMin = 45 * (pi / 180);

/// Maximum launch angle of a normal shot, in radians.
///
/// Tuned (M1-032a) from 45° to 55°.  At this angle a shot from the
/// defensive position (300, 520) reaches the opponent half at x ≈ 889, and
/// a shot from the near-net position (560, 520) lands at x ≈ 1149 — both
/// within the court boundary of 1240 — see test/engine/balance/.
const double kNormalShotAngleMax = 55 * (pi / 180);

/// Launch speed of a smash.
///
/// Unchanged at 16 game-units/tick.  The jump-smash bonus (16 × 1.15 = 18.4)
/// stays within kShuttleMaxVelocity (20).  At the tuned gravity and drag the
/// smash lands in the opponent half across the full angle range — see
/// test/engine/balance/.
const double kSmashSpeed = 16;

/// Minimum launch angle of a smash, in radians.
///
/// Unchanged at 10°.  At this shallow angle the smash still crosses the net
/// and lands well in bounds at the tuned constants.
const double kSmashAngleMin = 10 * (pi / 180);

/// Maximum launch angle of a smash, in radians.
///
/// Tuned (M1-032a) from 20° to 25°.  The steeper maximum allows a wider
/// tactical spread while still landing past the net (x > 640) — at 25° the
/// shuttle lands at x ≈ 686, just past the net — see test/engine/balance/.
const double kSmashAngleMax = 25 * (pi / 180);

/// Launch speed of a drop shot.
///
/// Tuned (M1-032a) from 5 to 7 game-units/tick.  The steeper launch angle
/// (kDropShotAngle) requires enough initial velocity to carry the shuttle
/// over the net; at speed 7 the drop clears the net (netCrossingY ≈ 337,
/// which is above the net top at 350) and lands short at x ≈ 794 — between
/// the net and the short-service line at 840 — see test/engine/balance/.
const double kDropShotSpeed = 7;

/// Launch angle of a drop shot, in radians.
///
/// Tuned (M1-032a) from 25° to 60°.  With the original 25° angle the shuttle
/// launched from y = 520 could never reach the net top at y = 350 — the
/// geometry requires an angle above ≈ 42° just to clear the height difference
/// without any physics forces.  At 60° the shuttle arcs high, clearing the
/// net cleanly, then the elevated drag (kShuttleDropShotDrag) kills the
/// horizontal speed and the shuttle drops short — see test/engine/balance/.
const double kDropShotAngle = 60 * (pi / 180);

/// Launch speed of a serve toss.
///
/// Tuned (M1-032a) from 4 to 9 game-units/tick.  The original value of 4
/// produced a near-vertical lob that travelled only ≈ 60 horizontal units —
/// a serve that could never reach the net at x = 640, let alone the
/// short-service line at x = 840.  At speed 9 with the tuned gravity (0.06)
/// and drag (0.001) the serve clears the net at y ≈ 299 and lands at
/// x ≈ 941 — past the short-service line and inside the baseline — see
/// test/engine/balance/.
const double kTossSpeed = 9;

/// Launch angle of a serve toss, in radians.
///
/// Tuned (M1-032a) from 75° to 45°.  The original 75° was a near-vertical
/// lob that maximised height but sacrificed all horizontal range.  45°
/// balances height (the shuttle arcs above the net top) with range (the
/// shuttle reaches the receiver's half).  The toss has no PRNG spread
/// (fixed angle), so a single trajectory determines compliance; see
/// test/engine/balance/.
const double kTossAngle = 45 * (pi / 180);

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

// ---------------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------------

/// Frames of input history captured in a crash report (M1-018).
const int kCrashInputHistoryFrames = 60;
