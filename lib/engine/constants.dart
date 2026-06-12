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
///
/// Rebalanced (geometry-rebalance): 350 → 470. The old net (350) stood 250
/// units tall vs an 80-unit player — 3× the player height. Real badminton's
/// net (1.55 m) is ≈ 85% of player height. At kPlayerHitboxHeight = 150 the
/// net height = kGroundY − kNetTopY = 600 − 470 = 130 units, which is 130/150
/// ≈ 87% — close to the real ratio. The lower net makes clearing EASIER, so
/// shot speeds and angle ranges were re-verified against the new geometry; see
/// kSmashAngleMax for the only angle constant that changed.
const double kNetTopY = 470;

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
///
/// Rebalanced (geometry-rebalance): 380 → 460. With kPlayerHitboxHeight = 150
/// the jump height = kGroundY − kPlayerJumpApexY = 600 − 460 = 140 units.
/// A grounded overhead contact at y ≈ 400 (hitbox top 450 − reach 50) already
/// clears the net top (470) without jumping; jumps are used for high
/// interceptions and to gain steeper smash angles.
const double kPlayerJumpApexY = 460;

/// Peak jump height above the ground, in game units.
const double kPlayerJumpHeight = kGroundY - kPlayerJumpApexY;

/// Duration of a jump arc, in ticks.
const int kPlayerJumpDuration = 40;

/// Player hitbox width in game units.
///
/// Rebalanced (geometry-rebalance): 48 → 60. Wider hitbox matches the taller
/// player proportionally and gives a slightly larger reach zone. Clamping
/// margins (kPlayer1StartX = kCourtLeftBound + 120 = 160; half-width = 30;
/// left outer bound = 40) still leave 90 units between the start position and
/// the outer wall — well within legal play.
const double kPlayerHitboxWidth = 60;

/// Player hitbox height in game units.
///
/// Rebalanced (geometry-rebalance): 80 → 150. Taller players improve
/// proportion vs the new net height (kNetTopY = 470; net = 130 units ≈ 87%
/// of player height, matching real badminton's ≈ 85%). The game-layer
/// PlayerComponent drawing is re-proportioned to match; see player_component.dart.
const double kPlayerHitboxHeight = 150;

/// Starting x of player 1 (left side).
const double kPlayer1StartX = kCourtLeftBound + 120;

/// Starting x of player 2 (right side).
const double kPlayer2StartX = kCourtRightBound - 120;

/// Horizontal offset from the server's centre toward the net at which the
/// shuttle is placed for a serve.
///
/// Rebalanced (geometry-rebalance): 40 → 50. Scales with the wider hitbox
/// (60) so the shuttle is still placed slightly in front of the body.
const double kServeShuttleOffsetX = 50;

/// Height above the ground at which the serve shuttle is placed.
///
/// Rebalanced (geometry-rebalance): 80 → 110. Represents waist height of
/// the taller 150-unit player (roughly y = kGroundY − kServeShuttleHeight =
/// 600 − 110 = 490, which is near the mid-body of a 150-unit hitbox whose
/// top sits at kGroundY − kPlayerHitboxHeight = 600 − 150 = 450).
const double kServeShuttleHeight = 110;

/// Extra horizontal and vertical reach the racquet adds to the player hitbox
/// on the facing side (and upward), in game units. Models the racquet arm
/// extending the effective contact zone in front of and above the body.
///
/// Rebalanced (geometry-rebalance): 40 → 50. Scales with the taller player;
/// the upward reach now extends from hitbox top (y = kGroundY −
/// kPlayerHitboxHeight = 450) to y = 450 − 50 = 400, which is well above the
/// new net top (470). Grounded overhead contact (y ≈ 405) is therefore just
/// inside the upward reach zone without jumping.
const double kRacquetReach = 50;

/// Speed multiplier applied to a smash hit while the player is airborne — the
/// genre-defining jump smash hits harder than a grounded smash.
const double kJumpSmashBonus = 1.15;

// ---------------------------------------------------------------------------
// Shuttle
// ---------------------------------------------------------------------------

/// Per-tick downward gravity applied to the shuttle (+y).
///
/// Tuned (M1-032a) from 0.15 → 0.06 to make shots physically reachable.
/// Retuned (M1-032a retune) from 0.06 → 0.14 to eliminate floatiness.
/// Unchanged at 0.14 through the geometry-rebalance. At 0.14, flight times
/// are 119–132 ticks for normals (2.0–2.2 s) and 120 ticks for serves with
/// the new geometry — snappy and followable.
const double kShuttleGravity = 0.14;

/// Quadratic-drag coefficient for normal flight.
///
/// Unchanged at 0.001 through all tuning passes. Unchanged through the
/// geometry-rebalance: high-speed shots retain their range across the court,
/// and gravity at 0.14 remains the primary landing-zone control.
const double kShuttleDragCoefficient = 0.001;

/// Quadratic-drag coefficient for drop shots (higher, bleeds speed faster).
///
/// Retuned (M1-032a retune) from 0.002 → 0.001 (same as normal flight).
/// Unchanged through the geometry-rebalance. From the new contact height
/// (450, 480), the 65° steep angle still delivers the shuttle inside the
/// short-service line (x ≈ 786 ≤ 840); the separate elevated drag is not
/// needed.
const double kShuttleDropShotDrag = 0.001;

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
/// Retuned (M1-032a retune) from 8 → 12 game-units/tick.
/// Unchanged at 12 through the geometry-rebalance: from the new grounded
/// drive contact y = 480 (hitbox top 450, waist ≈ 480), speed 12 at 45–55°
/// produces net-crossing y values of 249–299, well above the new net top
/// (470), and lands 886–954 from the defensive position (300, 480) in
/// 119–132 ticks (≤ 135 target).
const double kNormalShotSpeed = 12;

/// Minimum launch angle of a normal shot, in radians.
///
/// Unchanged at 45° through both retunes (M1-032a retune and
/// geometry-rebalance). At 45° with speed 12 and gravity 0.14, a defensive
/// shot from the new grounded-drive contact (300, 480) crosses the net at
/// y ≈ 299 (well above the new net top 470) and lands at x ≈ 954 in 119 ticks.
const double kNormalShotAngleMin = 45 * (pi / 180);

/// Maximum launch angle of a normal shot, in radians.
///
/// Unchanged at 55° through both retunes (M1-032a retune and
/// geometry-rebalance). At 55° with speed 12 and gravity 0.14, a defensive
/// shot from (300, 480) crosses the net at y ≈ 249 and lands at x ≈ 886 in
/// 132 ticks — well within the ≤ 135 tick target.
const double kNormalShotAngleMax = 55 * (pi / 180);

/// Launch speed of a smash.
///
/// Unchanged at 16 game-units/tick.  The jump-smash bonus (16 × 1.15 = 18.4)
/// stays within kShuttleMaxVelocity (20).
const double kSmashSpeed = 16;

/// Minimum launch angle of a smash, in radians.
///
/// Unchanged at 10° through all retunes. From the grounded-overhead contact
/// (450, 405) at gravity 0.14, the smash at 10° crosses the net at y ≈ 451
/// (above the new net top at 470) and lands at x ≈ 948 — in bounds and in
/// the opponent half. From the jump-overhead contact (450, 265) the margin
/// is larger: net crossing y ≈ 311.
const double kSmashAngleMin = 10 * (pi / 180);

/// Maximum launch angle of a smash, in radians.
///
/// Retuned (M1-032a retune) from 25° → 13°.
/// Re-retuned (geometry-rebalance) from 13° → 15°.
///
/// The lower net top (kNetTopY 470 vs old 350) opens more vertical angle
/// for a smash from grounded-overhead contact (y ≈ 405). At 15° the shuttle
/// crosses the net at y ≈ 469.2 (< 470 net top — just clears the tape);
/// at 15.3° the crossing reaches 470.4, hitting the tape. The range [10°,15°]
/// is still narrow, preserving the readable "hard downward shot" character,
/// and now allows both a grounded-overhead smash (from y ≈ 405) AND a
/// jump-overhead smash (from y ≈ 265) to clear the net cleanly. A smash from
/// a LOW contact (y ≈ 560, below the net top) still fails to reach the
/// opponent's court — empirically landing at x ≈ 619 (short of the net at
/// x = 640). See the balance tests for all empirical numbers.
const double kSmashAngleMax = 15 * (pi / 180);

/// Launch speed of a drop shot.
///
/// Retuned (M1-032a retune) from 7 → 9 game-units/tick.
/// Unchanged at 9 through the geometry-rebalance: from the new grounded-drive
/// contact (450, 480) at 65° and gravity 0.14, speed 9 produces net-crossing
/// y ≈ 304 (above the new net top 470) and lands at x ≈ 786, inside the
/// short-service line at 840, in 119 ticks (≤ the 120-tick target).
const double kDropShotSpeed = 9;

/// Launch angle of a drop shot, in radians.
///
/// Retuned (M1-032a retune) from 60° → 65°.
/// Unchanged at 65° through the geometry-rebalance. From the new contact
/// height (480 vs old 520), a 65° arc needs only a modest rise to clear the
/// lower net top (470 vs old 350). The net crossing margin is large: y ≈ 304,
/// 166 units above the tape. The landing zone (x ≈ 786) remains inside the
/// short-service line (840), preserving the drop shot's tactical distinctness.
const double kDropShotAngle = 65 * (pi / 180);

/// Minimum launch speed of a serve toss (shortest legal serve).
///
/// Introduced in M1-034 (hold-to-charge serve) to replace the removed
/// `kTossSpeed` constant. A short-tap (0 held ticks) launches at this speed.
///
/// Tuned at 43° from the serve start position (210, 490):
///   speed 12 → netCrossingY ≈ 343 (127 units above kNetTopY 470, well clear),
///   landingX ≈ 866 — past the short-service line (840) so it is LEGAL,
///   flight 114 ticks.
/// A brand-new player who taps once without charging cannot auto-fault.
const double kTossSpeedMin = 12;

/// Maximum launch speed of a serve toss (deepest charge, full hold).
///
/// Introduced in M1-034 (hold-to-charge serve) to replace the removed
/// `kTossSpeed` constant. A full-charge hold ([kServeChargeMaxTicks] ticks)
/// launches at this speed.
///
/// Tuned at 43° from the serve start position (210, 490):
///   speed 17 → netCrossingY ≈ 220 (250 units of clearance),
///   landingX ≈ 1137 — deep in the receiver court, 103 units short of
///   the baseline (1240), flight 139 ticks.
const double kTossSpeedMax = 17;

/// Launch angle of a serve toss, in radians.
///
/// Retuned (M1-032a retune) from 45° → 43°.
/// Unchanged at 43° through the geometry-rebalance (M1-033) and the
/// hold-to-charge serve (M1-034). At 43°, both [kTossSpeedMin] and
/// [kTossSpeedMax] satisfy the net-clearance (≥10 units) and legal-landing
/// requirements without any angle adjustment.
const double kTossAngle = 43 * (pi / 180);

/// Maximum ticks the server can hold the toss button to charge a full serve.
///
/// Introduced in M1-034. Charge fraction = held ticks / kServeChargeMaxTicks,
/// clamped to 1.0. At 60 ticks/sec this is 0.75 s to full charge, a
/// comfortable window for touch input.
const int kServeChargeMaxTicks = 45;

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
///
/// Raised from 300 → 600 in M1-034 (hold-to-charge serve). The charging
/// mechanic consumes serve time while the button is held, so the old 5 s
/// window was too tight for a player who wants to wind up a full charge
/// (0.75 s) after some movement. At 60 ticks/sec, 600 frames = 10 s.
const int kServeTimeoutFrames = 600;

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
