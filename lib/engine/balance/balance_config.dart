import 'package:meta/meta.dart';
import 'package:smash_bros/engine/constants.dart';

/// The runtime-tunable **feel** parameters of the simulation (M1-032).
///
/// ## Why this exists
///
/// Gameplay feel — how floaty the shuttle is, how fast shots travel, how
/// quickly stamina bleeds — must be tunable *without recompiling* so the rally
/// can be tuned to "fun" via the debug overlay (the Milestone 1 MVP gate). The
/// raw numbers still live as the `k*` defaults in `constants.dart`; this class
/// is the mutable-at-runtime mirror of the **feel** subset, loaded from
/// `assets/data/balance.json` at launch.
///
/// ## What belongs here (and what doesn't)
///
/// Only **feel** parameters: physics coefficients, launch speeds, the
/// jump-smash bonus, the player walk speed, and stamina drains/regen. These
/// are safe to slide at runtime and immediately re-feel.
///
/// Structural values stay compile-time constants in `Tunables`:
/// court geometry, the net position, hitbox dimensions, shot **angles**, and
/// the scoring rules. The carefully verified net-clearance math (see the
/// angle-constant docs in `constants.dart`) depends on those holding fixed;
/// exposing them as sliders would silently break legal-landing guarantees.
///
/// ## Engine purity & determinism
///
/// This is **pure Dart** (no Flutter, no asset loading) — the game layer reads
/// the JSON and hands the parsed map to [BalanceConfig.fromJson]. The active
/// config is applied once via `Tunables.apply` before a match starts and never
/// mutated mid-match, so a single match stays fully deterministic (the
/// existing 10k-tick determinism tests are unaffected: they run on
/// [BalanceConfig.defaults]). When Milestone 3 netcode needs two peers to
/// agree on balance, the config moves into `GameState`'s snapshot signature;
/// the field set defined here is what will serialize.
@immutable
final class BalanceConfig {
  /// Creates a config with every feel parameter given explicitly.
  const BalanceConfig({
    required this.shuttleGravity,
    required this.shuttleDragCoefficient,
    required this.shuttleDropShotDrag,
    required this.shuttleMaxVelocity,
    required this.netCordDamping,
    required this.normalShotSpeed,
    required this.smashSpeed,
    required this.dropShotSpeed,
    required this.jumpSmashBonus,
    required this.tossSpeedMin,
    required this.tossSpeedMax,
    required this.playerSpeed,
    required this.staminaDrainNormal,
    required this.staminaDrainSmash,
    required this.staminaDrainJump,
    required this.staminaDrainMove,
    required this.staminaRegen,
  });

  /// The shipped defaults, taken **directly** from the `k*` constants so the
  /// default config and `constants.dart` can never drift apart.
  const BalanceConfig.defaults()
    : shuttleGravity = kShuttleGravity,
      shuttleDragCoefficient = kShuttleDragCoefficient,
      shuttleDropShotDrag = kShuttleDropShotDrag,
      shuttleMaxVelocity = kShuttleMaxVelocity,
      netCordDamping = kNetCordDamping,
      normalShotSpeed = kNormalShotSpeed,
      smashSpeed = kSmashSpeed,
      dropShotSpeed = kDropShotSpeed,
      jumpSmashBonus = kJumpSmashBonus,
      tossSpeedMin = kTossSpeedMin,
      tossSpeedMax = kTossSpeedMax,
      playerSpeed = kPlayerSpeed,
      staminaDrainNormal = kStaminaDrainNormal,
      staminaDrainSmash = kStaminaDrainSmash,
      staminaDrainJump = kStaminaDrainJump,
      staminaDrainMove = kStaminaDrainMove,
      staminaRegen = kStaminaRegen;

  /// Parses a config from a decoded JSON map (e.g. `assets/data/balance.json`).
  ///
  /// Any key that is absent or non-numeric falls back to the [BalanceConfig.defaults] value
  /// for that field, so a partial or hand-edited JSON file degrades gracefully
  /// rather than throwing mid-launch.
  factory BalanceConfig.fromJson(Map<String, dynamic> json) {
    const d = BalanceConfig.defaults();
    double read(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return BalanceConfig(
      shuttleGravity: read('shuttleGravity', d.shuttleGravity),
      shuttleDragCoefficient: read(
        'shuttleDragCoefficient',
        d.shuttleDragCoefficient,
      ),
      shuttleDropShotDrag: read('shuttleDropShotDrag', d.shuttleDropShotDrag),
      shuttleMaxVelocity: read('shuttleMaxVelocity', d.shuttleMaxVelocity),
      netCordDamping: read('netCordDamping', d.netCordDamping),
      normalShotSpeed: read('normalShotSpeed', d.normalShotSpeed),
      smashSpeed: read('smashSpeed', d.smashSpeed),
      dropShotSpeed: read('dropShotSpeed', d.dropShotSpeed),
      jumpSmashBonus: read('jumpSmashBonus', d.jumpSmashBonus),
      tossSpeedMin: read('tossSpeedMin', d.tossSpeedMin),
      tossSpeedMax: read('tossSpeedMax', d.tossSpeedMax),
      playerSpeed: read('playerSpeed', d.playerSpeed),
      staminaDrainNormal: read('staminaDrainNormal', d.staminaDrainNormal),
      staminaDrainSmash: read('staminaDrainSmash', d.staminaDrainSmash),
      staminaDrainJump: read('staminaDrainJump', d.staminaDrainJump),
      staminaDrainMove: read('staminaDrainMove', d.staminaDrainMove),
      staminaRegen: read('staminaRegen', d.staminaRegen),
    );
  }

  // -- Shuttle physics --------------------------------------------------------

  /// Per-tick downward gravity applied to the shuttle (+y).
  final double shuttleGravity;

  /// Quadratic-drag coefficient for normal flight.
  final double shuttleDragCoefficient;

  /// Quadratic-drag coefficient for drop shots.
  final double shuttleDropShotDrag;

  /// Maximum shuttle speed in game units per tick (stability safeguard).
  final double shuttleMaxVelocity;

  /// Velocity-scaling factor applied when the shuttle clips the net cord.
  final double netCordDamping;

  // -- Shots ------------------------------------------------------------------

  /// Launch speed of a normal clear/drive shot.
  final double normalShotSpeed;

  /// Launch speed of a smash.
  final double smashSpeed;

  /// Launch speed of a drop shot.
  final double dropShotSpeed;

  /// Speed multiplier applied to a smash hit while airborne (the jump smash).
  final double jumpSmashBonus;

  /// Minimum launch speed of a serve toss (short tap).
  final double tossSpeedMin;

  /// Maximum launch speed of a serve toss (full charge).
  final double tossSpeedMax;

  // -- Player -----------------------------------------------------------------

  /// Horizontal movement speed in game units per tick.
  final double playerSpeed;

  // -- Stamina ----------------------------------------------------------------

  /// Stamina drained by a normal (or drop) shot.
  final double staminaDrainNormal;

  /// Stamina drained by a smash.
  final double staminaDrainSmash;

  /// Stamina drained by a jump.
  final double staminaDrainJump;

  /// Stamina drained per tick of movement.
  final double staminaDrainMove;

  /// Stamina regained per tick while idle and grounded.
  final double staminaRegen;

  /// Returns a copy with the given fields replaced — the tuning overlay edits
  /// one slider at a time and re-applies the result.
  BalanceConfig copyWith({
    double? shuttleGravity,
    double? shuttleDragCoefficient,
    double? shuttleDropShotDrag,
    double? shuttleMaxVelocity,
    double? netCordDamping,
    double? normalShotSpeed,
    double? smashSpeed,
    double? dropShotSpeed,
    double? jumpSmashBonus,
    double? tossSpeedMin,
    double? tossSpeedMax,
    double? playerSpeed,
    double? staminaDrainNormal,
    double? staminaDrainSmash,
    double? staminaDrainJump,
    double? staminaDrainMove,
    double? staminaRegen,
  }) {
    return BalanceConfig(
      shuttleGravity: shuttleGravity ?? this.shuttleGravity,
      shuttleDragCoefficient:
          shuttleDragCoefficient ?? this.shuttleDragCoefficient,
      shuttleDropShotDrag: shuttleDropShotDrag ?? this.shuttleDropShotDrag,
      shuttleMaxVelocity: shuttleMaxVelocity ?? this.shuttleMaxVelocity,
      netCordDamping: netCordDamping ?? this.netCordDamping,
      normalShotSpeed: normalShotSpeed ?? this.normalShotSpeed,
      smashSpeed: smashSpeed ?? this.smashSpeed,
      dropShotSpeed: dropShotSpeed ?? this.dropShotSpeed,
      jumpSmashBonus: jumpSmashBonus ?? this.jumpSmashBonus,
      tossSpeedMin: tossSpeedMin ?? this.tossSpeedMin,
      tossSpeedMax: tossSpeedMax ?? this.tossSpeedMax,
      playerSpeed: playerSpeed ?? this.playerSpeed,
      staminaDrainNormal: staminaDrainNormal ?? this.staminaDrainNormal,
      staminaDrainSmash: staminaDrainSmash ?? this.staminaDrainSmash,
      staminaDrainJump: staminaDrainJump ?? this.staminaDrainJump,
      staminaDrainMove: staminaDrainMove ?? this.staminaDrainMove,
      staminaRegen: staminaRegen ?? this.staminaRegen,
    );
  }

  /// A JSON map mirroring [BalanceConfig.fromJson] — used to author/round-trip
  /// the asset.
  Map<String, dynamic> toJson() => {
    'shuttleGravity': shuttleGravity,
    'shuttleDragCoefficient': shuttleDragCoefficient,
    'shuttleDropShotDrag': shuttleDropShotDrag,
    'shuttleMaxVelocity': shuttleMaxVelocity,
    'netCordDamping': netCordDamping,
    'normalShotSpeed': normalShotSpeed,
    'smashSpeed': smashSpeed,
    'dropShotSpeed': dropShotSpeed,
    'jumpSmashBonus': jumpSmashBonus,
    'tossSpeedMin': tossSpeedMin,
    'tossSpeedMax': tossSpeedMax,
    'playerSpeed': playerSpeed,
    'staminaDrainNormal': staminaDrainNormal,
    'staminaDrainSmash': staminaDrainSmash,
    'staminaDrainJump': staminaDrainJump,
    'staminaDrainMove': staminaDrainMove,
    'staminaRegen': staminaRegen,
  };

  @override
  bool operator ==(Object other) =>
      other is BalanceConfig &&
      other.shuttleGravity == shuttleGravity &&
      other.shuttleDragCoefficient == shuttleDragCoefficient &&
      other.shuttleDropShotDrag == shuttleDropShotDrag &&
      other.shuttleMaxVelocity == shuttleMaxVelocity &&
      other.netCordDamping == netCordDamping &&
      other.normalShotSpeed == normalShotSpeed &&
      other.smashSpeed == smashSpeed &&
      other.dropShotSpeed == dropShotSpeed &&
      other.jumpSmashBonus == jumpSmashBonus &&
      other.tossSpeedMin == tossSpeedMin &&
      other.tossSpeedMax == tossSpeedMax &&
      other.playerSpeed == playerSpeed &&
      other.staminaDrainNormal == staminaDrainNormal &&
      other.staminaDrainSmash == staminaDrainSmash &&
      other.staminaDrainJump == staminaDrainJump &&
      other.staminaDrainMove == staminaDrainMove &&
      other.staminaRegen == staminaRegen;

  @override
  int get hashCode => Object.hashAll([
    shuttleGravity,
    shuttleDragCoefficient,
    shuttleDropShotDrag,
    shuttleMaxVelocity,
    netCordDamping,
    normalShotSpeed,
    smashSpeed,
    dropShotSpeed,
    jumpSmashBonus,
    tossSpeedMin,
    tossSpeedMax,
    playerSpeed,
    staminaDrainNormal,
    staminaDrainSmash,
    staminaDrainJump,
    staminaDrainMove,
    staminaRegen,
  ]);
}
