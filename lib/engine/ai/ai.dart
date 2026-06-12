/// AI controller abstractions and implementations for Arcade Badminton.
///
/// The AI lives outside the deterministic simulation core — it is an
/// "artificial thumb" that writes into a player's input buffer before
/// each tick. See `AIController` for the full architecture rationale.
library;

export 'ai_controller.dart';
export 'basic_ai.dart';
