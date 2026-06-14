import 'package:smash_bros/engine/ai/ai_controller.dart';
import 'package:smash_bros/engine/ai/basic_ai.dart';
import 'package:smash_bros/engine/ai/challenging_ai.dart';
import 'package:smash_bros/engine/ai/hard_ai.dart';
import 'package:smash_bros/engine/ai/intermediate_ai.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/random/game_random.dart';

/// The AI opponent skill tiers and their controller factory.
///
/// Until the Milestone 2D difficulty screen lands, the game layer assigns a
/// tier **at random per match** via [roll] — the player never knows which
/// opponent they drew until the rally starts.
enum AiDifficulty {
  /// `BasicAI` — 15-tick reaction, chases the shuttle's current x, 70/20/10
  /// shot mix. The original M1-028 opponent.
  easy,

  /// `IntermediateAI` — 12-tick reaction, predicts the landing spot but with
  /// looser positioning, calmer 65/25/10 shot mix. The rung between easy and
  /// hard (M2-022).
  intermediate,

  /// `HardAI` — 8-tick reaction, predicts the shuttle's landing x and walks
  /// there early, more aggressive 50/35/15 shot mix.
  hard,

  /// `ChallengingAI` — 3-tick reaction (the M2-023 HardAI spec), trajectory
  /// prediction, and context-aware shot selection (jump-smash on high
  /// shuttles, drops near the net).
  challenging;

  /// A short title-cased label for the difficulty-select screen.
  String get displayName => switch (this) {
    AiDifficulty.easy => 'Easy',
    AiDifficulty.intermediate => 'Intermediate',
    AiDifficulty.hard => 'Hard',
    AiDifficulty.challenging => 'Challenging',
  };

  /// Rolls a tier deterministically from [seed].
  ///
  /// Uses a throwaway [GameRandom] so the choice is reproducible from the
  /// seed alone and no shared PRNG stream is perturbed (ADR-8 discipline,
  /// even though this runs in the game layer).
  static AiDifficulty roll(int seed) =>
      values[GameRandom(seed).nextInt(values.length)];

  /// Builds the [AIController] implementing this tier for [side], seeding
  /// its private PRNG with [seed].
  AIController build({required CourtSide side, required int seed}) {
    switch (this) {
      case AiDifficulty.easy:
        return BasicAI(side: side, seed: seed);
      case AiDifficulty.intermediate:
        return IntermediateAI(side: side, seed: seed);
      case AiDifficulty.hard:
        return HardAI(side: side, seed: seed);
      case AiDifficulty.challenging:
        return ChallengingAI(side: side, seed: seed);
    }
  }
}
