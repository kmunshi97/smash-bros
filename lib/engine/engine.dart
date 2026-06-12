/// The pure-Dart simulation engine — the single public surface the game
/// (Flame) layer imports.
///
/// This barrel re-exports every engine subsystem (constants, math, random,
/// entities, input, systems, rules, sim) so consumers depend on `engine.dart`
/// alone rather than reaching into individual files. The engine never imports
/// `package:flutter` or `package:flame`; it produces state the rendering layer
/// reads (see CLAUDE.md "Architecture rules").
library;

export 'constants.dart';
export 'entities/entities.dart';
export 'input/input.dart';
export 'math/fix.dart';
export 'math/fix_vec2.dart';
export 'random/game_random.dart';
export 'render/render.dart';
export 'rules/rules.dart';
export 'sim/sim.dart';
export 'systems/systems.dart';
