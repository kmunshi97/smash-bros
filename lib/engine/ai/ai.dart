/// AI controller abstractions and implementations for Arcade Badminton.
///
/// The AI lives outside the deterministic simulation core — it is an
/// "artificial thumb" that writes into a player's input buffer before
/// each tick. See `AIController` for the full architecture rationale.
///
/// Three difficulty tiers exist (`AiDifficulty`): easy (`BasicAI`), hard
/// (`HardAI`) and challenging (`ChallengingAI`), all built on the shared
/// `RuleBasedAi` skeleton. The game layer rolls a tier at random per match
/// via `AiDifficulty.roll`.
library;

export 'ai_controller.dart';
export 'ai_difficulty.dart';
export 'basic_ai.dart';
export 'challenging_ai.dart';
export 'hard_ai.dart';
export 'rule_based_ai.dart';
export 'shuttle_predictor.dart';
