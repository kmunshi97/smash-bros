import 'dart:math';

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------

const int kTickRate = 60;
const double kTickDuration = 1.0 / kTickRate;

// ---------------------------------------------------------------------------
// Court (game-unit coordinate system)
// ---------------------------------------------------------------------------

const double kCourtWidth = 1280;
const double kCourtHeight = 720;
const double kNetX = kCourtWidth / 2;
const double kNetTopY = 350;
const double kGroundY = 600;

const double kCourtLeftBound = 40;
const double kCourtRightBound = kCourtWidth - 40;

const double kShortServeLineLeft = kNetX - 200;
const double kShortServeLineRight = kNetX + 200;

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

const double kPlayerSpeed = 6;
const double kPlayerJumpApexY = 380;
const double kPlayerJumpHeight = kGroundY - kPlayerJumpApexY;
const int kPlayerJumpDuration = 40;
const double kPlayerHitboxWidth = 48;
const double kPlayerHitboxHeight = 80;

const double kPlayer1StartX = kCourtLeftBound + 120;
const double kPlayer2StartX = kCourtRightBound - 120;

// ---------------------------------------------------------------------------
// Shuttle
// ---------------------------------------------------------------------------

const double kShuttleGravity = 0.15;
const double kShuttleDragCoefficient = 0.003;
const double kShuttleDropShotDrag = 0.006;
const double kShuttleMaxVelocity = 20;
const double kShuttleRadius = 6;

// Shot launch parameters
const double kNormalShotSpeed = 8;
const double kNormalShotAngleMin = 35 * (pi / 180);
const double kNormalShotAngleMax = 45 * (pi / 180);

const double kSmashSpeed = 16;
const double kSmashAngleMin = 10 * (pi / 180);
const double kSmashAngleMax = 20 * (pi / 180);

const double kDropShotSpeed = 5;
const double kDropShotAngle = 25 * (pi / 180);

const double kTossSpeed = 4;
const double kTossAngle = 75 * (pi / 180);

// ---------------------------------------------------------------------------
// Timing (in frames at 60 fps)
// ---------------------------------------------------------------------------

const int kPerfectBlockWindowStart = 6;
const int kPerfectBlockWindowEnd = 12;
const int kSwingAnimationFrames = 12;
const int kStunDurationFrames = 60;
const int kServeTimeoutFrames = 300;

// ---------------------------------------------------------------------------
// Stamina
// ---------------------------------------------------------------------------

const double kStaminaMax = 100;
const double kStaminaDrainNormal = 5;
const double kStaminaDrainSmash = 15;
const double kStaminaDrainJump = 8;
const double kStaminaDrainMove = 0.5;
const double kStaminaRegen = 0.3;
const double kStaminaDebuffThreshold = 30;
const double kStaminaMinMultiplier = 0.5;

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

const int kDefaultTargetScore = 11;
const int kDeuceThreshold = 10;
const int kDeuceLeadRequired = 2;
const int kDeuceCap = 15;

// ---------------------------------------------------------------------------
// Rollback / Netcode (Milestone 3, defined early for buffer sizing)
// ---------------------------------------------------------------------------

const int kMaxRollbackFrames = 600;
const int kSnapshotInterval = 6;
