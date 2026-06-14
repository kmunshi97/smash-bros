import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

/// Visual theme for a procedurally-drawn arena (M2 court rework).
///
/// The court markings and net are drawn in code at exact dimensions; only the
/// **floor** changes between arenas. Swapping this theme (or just its floor
/// colours / texture) re-skins the whole court — "change the floor to change
/// the arena" — without touching geometry.
///
/// Pure data; no Flame/engine dependency.
@immutable
class ArenaTheme {
  /// Creates a theme with explicit colours.
  const ArenaTheme({
    required this.name,
    required this.floorNear,
    required this.floorFar,
    required this.floorTextureLine,
    required this.lineColor,
    required this.lineShadow,
    required this.netCord,
    required this.netMesh,
    required this.postLight,
    required this.postDark,
  });

  /// Indoor sports-hall green — the default look.
  static const ArenaTheme indoorGreen = ArenaTheme(
    name: 'Indoor Green',
    floorNear: Color(0xFF2F6B33),
    floorFar: Color(0xFF1C4521),
    floorTextureLine: Color(0x22000000),
    lineColor: Color(0xFFF5F7F2),
    lineShadow: Color(0x66000000),
    netCord: Color(0xFFF5F7F2),
    netMesh: Color(0x99D9E0E8),
    postLight: Color(0xFF6B7480),
    postDark: Color(0xFF2A2F38),
  );

  /// Warm clay/wood court — an example alternate arena (proves the swap).
  static const ArenaTheme clayCourt = ArenaTheme(
    name: 'Clay Court',
    floorNear: Color(0xFFB5683C),
    floorFar: Color(0xFF7E4527),
    floorTextureLine: Color(0x22000000),
    lineColor: Color(0xFFF7F0E6),
    lineShadow: Color(0x66000000),
    netCord: Color(0xFFF7F0E6),
    netMesh: Color(0x99E8DFD2),
    postLight: Color(0xFF8A6A52),
    postDark: Color(0xFF3A2A20),
  );

  /// Display name (for a future arena picker).
  final String name;

  /// Floor colour at the near edge (brighter, lit).
  final Color floorNear;

  /// Floor colour at the far edge (darker, in shade).
  final Color floorFar;

  /// Faint line colour for the floor's subtle plank/tile texture.
  final Color floorTextureLine;

  /// Court-marking line colour.
  final Color lineColor;

  /// Soft drop-shadow under court lines (depth cue / lighting).
  final Color lineShadow;

  /// Net tape / cord colour.
  final Color netCord;

  /// Net mesh colour (semi-transparent).
  final Color netMesh;

  /// Lit edge of the net posts.
  final Color postLight;

  /// Shaded edge of the net posts.
  final Color postDark;
}
