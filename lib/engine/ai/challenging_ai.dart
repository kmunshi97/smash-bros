import 'package:smash_bros/engine/ai/ai_difficulty.dart';
import 'package:smash_bros/engine/ai/hard_ai.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/input/input_action.dart';
import 'package:smash_bros/engine/sim/game_state.dart';

/// Below this share of `nextInt(100)` draws the deep-court shot is a normal
/// clear; the rest are drops to pull the opponent forward (60/40).
const int _kMixedRangeNormalMax = 60;

/// Horizontal distance from the net (game units) within which the
/// challenging tier plays a drop shot instead of rolling the mix — matches
/// the short-service-line distance (`kShortServeLine* = kNetX ± 200`).
const double _kNetDropDistance = 200;

/// Share of `nextInt(100)` draws (per inbound shuttle) on which the
/// challenging tier commits to returning the shot. The remaining ~10 % are
/// deliberately let go so the top tier is hard but still beatable — it gets
/// roughly nine of every ten shots back.
const int _kReturnReliabilityPercent = 90;

/// The top tier: the M2-023 "HardAI" spec pulled forward.
///
/// Inherits [HardAI]'s predictive positioning (walk to where the shuttle
/// will descend, not where it is) and sharpens everything else:
///
/// * **3-tick reaction delay** — the M2-023 spec value; near-instant.
/// * **Tighter movement dead zone** (4 units) — stands almost exactly on the
///   intercept point.
/// * **Context-aware shot selection** instead of a fixed mix:
///   - smash geometry clears the net (high contact, close enough — see
///     `HardAI.smashClearsNet`) → **jump smash**, every time;
///   - otherwise, inside the short-service-line distance from the net →
///     **drop shot** just over the tape;
///   - otherwise a 60/40 normal/drop roll from the private PRNG (a smash
///     from deep or low contact would hit the tape, so it is never rolled).
///
/// * **~90 % return reliability**: on each inbound shuttle it rolls once
///   ([_kReturnReliabilityPercent]) whether to commit to the return. On the
///   ~10 % it does not, it tracks the shuttle as usual but never swings — a
///   natural-looking whiff that keeps the top tier beatable.
///
/// Jump is only ever emitted alongside smash (M1-036 invariant holds for
/// every tier).
final class ChallengingAI extends HardAI {
  /// Creates a [ChallengingAI] for [side] with its private PRNG [seed].
  ChallengingAI({required super.side, required super.seed});

  /// Whether the current inbound shuttle will be returned (rolled once per
  /// crossing in [onInboundShuttle]). `false` → deliberately whiff this rally.
  bool _returnThisRally = true;

  @override
  AiDifficulty get difficulty => AiDifficulty.challenging;

  @override
  int get serveTossDelayTicks => 20; // ≈ 0.33 s — barely pauses.

  @override
  int get reactionDelayTicks => 3; // M2-023 spec value.

  @override
  double get movementDeadZone => 4;

  @override
  void onInboundShuttle(GameState state) {
    // Commit (or not) to this return — a fresh roll for every inbound shot.
    _returnThisRally = random.nextInt(100) < _kReturnReliabilityPercent;
  }

  @override
  int chooseShotBit(GameState state) {
    // The ~10 % of returns we let go: in reach but never swing → a clean miss.
    if (!_returnThisRally) return InputAction.none;

    final shuttleX = state.shuttle.position.x.toDouble();

    // The smash geometry clears the net → take the kill.
    if (smashClearsNet(state)) {
      return InputAction.jump | InputAction.smash;
    }

    // Close to the net → drop it just over the tape.
    if ((shuttleX - kNetX).abs() <= _kNetDropDistance) {
      return InputAction.dropShot;
    }

    // Deep or low contact: mix safe clears with the occasional drop to pull
    // the opponent forward. Smashing from here would hit the tape (see
    // `smashClearsNet`), so it is never rolled.
    final roll = random.nextInt(100);
    if (roll < _kMixedRangeNormalMax) return InputAction.normalShot;
    return InputAction.dropShot;
  }
}
