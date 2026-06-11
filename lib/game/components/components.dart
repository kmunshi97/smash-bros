/// Flame render components for Arcade Badminton (M1-022..024).
///
/// Each component is pure presentation: it reads `BadmintonGame.view` and
/// emits draw calls — no game logic, no direct simulation access.
library;

export 'court_component.dart';
export 'player_component.dart';
export 'shuttle_component.dart';
