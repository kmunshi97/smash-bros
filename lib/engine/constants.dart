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
/// Tuned (M1-032a) from 0.15 → 0.06 to make shots physically reachable.
/// Retuned (M1-032a retune) from 0.06 → 0.14 to eliminate floatiness.
/// At 0.06 every shot took 3+ seconds in the air (177–198 ticks for a normal
/// clear), feeling like slow motion for an arcade title.  At 0.14 flight times
/// drop to 114–128 ticks for normals (1.9–2.1 s) and 117 ticks for serves
/// (≈ 2.0 s), which is snappy but still followable on screen.
/// Higher launch speeds compensate so every shot still crosses the net.
const double kShuttleGravity = 0.14;

/// Quadratic-drag coefficient for normal flight.
///
/// Unchanged at 0.001 through both tuning passes (M1-032a and retune).  The
/// value is low enough that high-speed shots (clears, smashes) retain their
/// range and cross to the opponent half without stalling, while gravity at
/// 0.14 provides the primary landing-speed control.
const double kShuttleDragCoefficient = 0.001;

/// Quadratic-drag coefficient for drop shots (higher, bleeds speed faster).
///
/// Retuned (M1-032a retune) from 0.002 → 0.001 (same as normal flight).
/// At the new gravity (0.14) and steeper drop angle (65°) the shuttle already
/// lands short — between the net and the short-service line (640–840) — using
/// the same drag as a normal shot.  The higher angle is now the primary
/// differentiator of the drop shot's short-range character; a separate drag
/// coefficient is no longer needed and would overly dampen the shot under the
/// stronger gravity.  See empirical result: drop from (450, 520) at 65°/9
/// units/tick lands at x ≈ 778 — inside the 840 short-service line.
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
/// Retuned (M1-032a retune) from 8 → 12 game-units/tick.  At the new
/// gravity (0.14), the original speed of 8 produced net-crossing y values of
/// ~475–515 — hitting the net body.  Speed 12 at the 45°–55° angle range
/// produces net-crossing y values of 286–338, well above the net top (350),
/// and lands 875–938 from the defensive position (300, 520) in ≤ 128 ticks.
const double kNormalShotSpeed = 12;

/// Minimum launch angle of a normal shot, in radians.
///
/// Unchanged at 45° through the retune (M1-032a retune).  At 45° with
/// speed 12 and gravity 0.14, a defensive shot from (300, 520) crosses the
/// net at y ≈ 338 (above the 350 net top) and lands at x ≈ 938 in 114 ticks.
/// See test/engine/balance/ for the near-net scenario note.
const double kNormalShotAngleMin = 45 * (pi / 180);

/// Maximum launch angle of a normal shot, in radians.
///
/// Unchanged at 55° through the retune (M1-032a retune).  At 55° with
/// speed 12 and gravity 0.14, a defensive shot from (300, 520) crosses the
/// net at y ≈ 286 and lands at x ≈ 875 in 128 ticks — within bounds and
/// well below the ≤ 135 tick flight-time target.
const double kNormalShotAngleMax = 55 * (pi / 180);

/// Launch speed of a smash.
///
/// Unchanged at 16 game-units/tick.  The jump-smash bonus (16 × 1.15 = 18.4)
/// stays within kShuttleMaxVelocity (20).
const double kSmashSpeed = 16;

/// Minimum launch angle of a smash, in radians.
///
/// Unchanged at 10°.  From the corrected jump-contact position (450, 290)
/// at gravity 0.14, the smash at 10° crosses the net at y ≈ 336 (above the
/// net top at 350) and lands at x ≈ 1089 — in bounds and in opponent half.
const double kSmashAngleMin = 10 * (pi / 180);

/// Maximum launch angle of a smash, in radians.
///
/// Retuned (M1-032a retune) from 25° → 13°.  The previous test scenario
/// launched from (450, 480) — 130 units below the net top — which was
/// physically incoherent for a jump smash; a real jump-smash contact is at
/// racquet height ≈ y 260–290.  With the corrected launch position (450, 290)
/// and gravity 0.14, the maximum angle at which the shuttle still clears the
/// net (crossing y < 350) is 13°; at 14° the crossing y = 350.4 hits the
/// tape.  The tighter range [10°, 13°] matches the narrow downward window of
/// a genuine hard smash and makes smash direction more predictable/readable
/// for players — wide angle spreads are the province of drops and clears.
const double kSmashAngleMax = 13 * (pi / 180);

/// Launch speed of a drop shot.
///
/// Retuned (M1-032a retune) from 7 → 9 game-units/tick.  At gravity 0.14
/// the original speed of 7 at 65° produced a net crossing y ≈ 479 — below
/// the net body.  Speed 9 at 65° produces crossing y ≈ 342 (above the
/// 350 net top) and lands at x ≈ 778, inside the short-service line at 840,
/// in 115 ticks (≤ the 120-tick flight-time target).
const double kDropShotSpeed = 9;

/// Launch angle of a drop shot, in radians.
///
/// Retuned (M1-032a retune) from 60° → 65°.  At gravity 0.14 and speed 9,
/// 65° provides the minimum vertical impulse needed to arc the shuttle over
/// the net (from y = 520 to net top y = 350, a 170-unit rise over 190 units
/// of horizontal distance).  The steeper angle keeps the landing short while
/// the unified drag coefficient (kShuttleDropShotDrag = 0.001) is sufficient
/// — no separate elevated drag is required under the stronger gravity.
const double kDropShotAngle = 65 * (pi / 180);

/// Launch speed of a serve toss.
///
/// Retuned (M1-032a retune) from 9 → 13 game-units/tick.  At gravity 0.14
/// the original speed of 9 at 45° produced a net crossing y ≈ 577 — hitting
/// the net body.  Speed 13 at 43° crosses the net at y ≈ 338 (above the 340
/// threshold, well above the 350 net top) and lands at x ≈ 904, past the
/// short-service line (840) and inside the baseline (1240), in 117 ticks
/// (≤ the 135-tick flight-time target).
const double kTossSpeed = 13;

/// Launch angle of a serve toss, in radians.
///
/// Retuned (M1-032a retune) from 45° → 43°.  Slightly shallower than 45°
/// increases horizontal range while gravity 0.14 keeps the arc tight enough
/// to clear the net above the 340 clearance threshold.  The toss has no PRNG
/// spread (fixed angle), so a single trajectory determines compliance.
const double kTossAngle = 43 * (pi / 180);

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
