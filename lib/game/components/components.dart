/// Flame render and input components for Arcade Badminton (M1-022..025).
///
/// Render components are pure presentation: they read `BadmintonGame.view` and
/// emit draw calls — no game logic, no direct simulation access.
/// Input components (M1-025) write into `BadmintonGame.controls` and render
/// touch targets; they do not read the simulation directly.
library;

export 'action_buttons_component.dart';
export 'court_component.dart';
export 'move_pad_component.dart';
export 'player_component.dart';
export 'shuttle_component.dart';
