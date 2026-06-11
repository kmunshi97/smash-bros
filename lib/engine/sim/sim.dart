/// Simulation core: the root `GameState`, the per-tick `Simulation`
/// orchestrator, the crash-safe error handler, and the fixed-timestep driver
/// (M1-017..019).
library;

export 'fixed_timestep_driver.dart';
export 'game_state.dart';
export 'match_error_handler.dart';
export 'simulation.dart';
