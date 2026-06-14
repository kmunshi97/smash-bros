import 'package:meta/meta.dart';

/// A lightweight player-profile view-model for the menu header (M2 V1).
///
/// Placeholder data for now — level, currencies and energy are demo values
/// shown in the home status bar. When the Milestone-3 economy/auth backend
/// lands, this is replaced by real values fetched per session; the header
/// widgets read this shape unchanged.
@immutable
class PlayerProfile {
  /// Creates a profile with explicit fields.
  const PlayerProfile({
    required this.name,
    required this.level,
    required this.energy,
    required this.maxEnergy,
    required this.coins,
    required this.gems,
  });

  /// The demo profile shown until the backend provides real data.
  static const PlayerProfile demo = PlayerProfile(
    name: 'Player',
    level: 7,
    energy: 70,
    maxEnergy: 70,
    coins: 1000,
    gems: 50,
  );

  /// Display name.
  final String name;

  /// Account level (badge on the avatar).
  final int level;

  /// Current energy / stamina-to-play.
  final int energy;

  /// Energy cap.
  final int maxEnergy;

  /// Soft currency.
  final int coins;

  /// Hard currency.
  final int gems;
}
