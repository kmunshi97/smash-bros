import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:smash_bros/engine/balance/balance.dart';

/// Loads the feel-tuning [BalanceConfig] from the bundled asset (M1-032).
///
/// This is the game-layer bridge that keeps the engine pure: the engine never
/// touches `rootBundle` or `dart:convert`. We read `assets/data/balance.json`
/// here, parse it into a [BalanceConfig], and the caller applies it via
/// `Tunables.apply` before constructing the simulation.
///
/// On any failure (missing asset, malformed JSON) the loader logs in debug and
/// falls back to [BalanceConfig.defaults] so the app always boots playable.
abstract final class BalanceLoader {
  /// The asset path of the balance file.
  static const String assetPath = 'assets/data/balance.json';

  /// Loads and parses the balance config, falling back to defaults on error.
  static Future<BalanceConfig> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const BalanceConfig.defaults();
      }
      return BalanceConfig.fromJson(decoded);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'BalanceLoader: failed to load $assetPath — using '
          'defaults. Error: $error\n$stackTrace',
        );
      }
      return const BalanceConfig.defaults();
    }
  }
}
