/// Runtime-tunable gameplay feel configuration (M1-032).
///
/// `BalanceConfig` is the pure-Dart value object holding the feel parameters
/// (physics, speeds, stamina). The game layer loads it from
/// `assets/data/balance.json` and applies it via `Tunables.apply`; the debug
/// tuning overlay edits it live.
library;

export 'balance_config.dart';
