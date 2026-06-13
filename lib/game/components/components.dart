/// Flame render and input components for Arcade Badminton (M1-022..026).
///
/// Render components are pure presentation: they read `BadmintonGame.view` and
/// emit draw calls — no game logic, no direct simulation access.
/// Input components (M1-025) write into `BadmintonGame.controls` and render
/// touch targets; they do not read the simulation directly.
/// HUD components (M1-026) live in the viewport and read `BadmintonGame.view`.
/// Effect components (M2-003/004/030) react to `BadmintonGame.frameEvents`
/// with particles and haptics — pure presentation, no simulation access.
library;

export 'action_buttons_component.dart';
export 'court_component.dart';
export 'effects/haptics_component.dart';
export 'effects/impact_effects_component.dart';
export 'hud/hud.dart';
export 'move_pad_component.dart';
export 'player_component.dart';
export 'shuttle_component.dart';
