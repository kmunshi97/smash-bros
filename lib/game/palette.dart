import 'package:flutter/painting.dart';
import 'package:smash_bros/ui/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Game render palette (M1-022..024)
//
// Single source-of-truth for every colour used by the Flame components in
// PR 2 and PR 3. Reuses AppColors hex values wherever they align with the
// arcade dark look; introduces new constants only where no AppColors entry
// exists.
// ---------------------------------------------------------------------------

/// All colours used by the Flame render layer.
///
/// `abstract final` prevents instantiation and subclassing; fields are
/// `static const` so they resolve at compile time with no allocation.
///
/// Components must read colours exclusively from this class. Do NOT inline
/// colour literals in component `render` methods — feel-tuning must be a
/// one-file change here.
abstract final class GamePalette {
  // -- Background -------------------------------------------------------------

  /// Deep-space background fill behind the play area.
  ///
  /// Matches [AppColors.darker] so the full-screen background is consistent
  /// with the app's dark theme outside the game.
  static const Color background = AppColors.darker; // 0xFF23272A

  // -- Court floor & markings ------------------------------------------------

  /// Court floor colour — the filled ground band below the ground plane.
  ///
  /// Reuses [AppColors.court], a dark-green arcade felt.
  static const Color courtFloor = AppColors.court; // 0xFF2D5A27

  /// White court-boundary and service-line markings.
  ///
  /// Reuses [AppColors.courtLines].
  static const Color courtLines = AppColors.courtLines; // 0xFFFFFFFF

  // -- Net --------------------------------------------------------------------

  /// Net body colour — the area between the tape bottom and the ground plane.
  ///
  /// Reuses [AppColors.net], a dark charcoal so the net reads as a solid
  /// obstacle without dominating the scene.
  static const Color netBody = AppColors.net; // 0xFF444444

  /// Net tape band — the brighter strip at the very top of the net.
  ///
  /// Slightly lighter than [netBody] to make the tape visually distinct and
  /// to communicate the net-cord mechanic to the player.
  static const Color netTape = Color(0xFF888888);

  // -- Players ----------------------------------------------------------------

  /// Left player body colour — blue tinted, matches [AppColors.player1].
  static const Color leftPlayer = AppColors.player1; // 0xFF4A90D9

  /// Right player body colour — red tinted, matches [AppColors.player2].
  static const Color rightPlayer = AppColors.player2; // 0xFFD94A4A

  /// Stun-flash overlay colour — bright white at 70% alpha.
  ///
  /// Blended over the player rect every other blink-frame while stunned so
  /// the stun state is immediately visible without obscuring the player shape.
  static const Color stunFlash = Color(0xB3FFFFFF); // white @ 70% alpha

  // -- Shuttle ----------------------------------------------------------------

  /// Shuttle fill colour — pure white so the cork reads clearly against the
  /// dark court and the dark sky.
  ///
  /// Reuses [AppColors.shuttle].
  static const Color shuttle = AppColors.shuttle; // 0xFFFFFFFF

  /// Trail segment base colour — white with reduced alpha; each segment fades
  /// further as components age it from newest (index 0) to oldest (index 23).
  ///
  /// Components multiply this base opacity by `(1 - age/24)` per segment.
  static const Color shuttleTrail = Color(0x66FFFFFF); // white @ 40% alpha

  // -- Controls ---------------------------------------------------------------

  /// Accent colour for the context-sensitive serve (TOSS) button — gold, so
  /// the serve affordance reads as distinct from the rally actions.
  static const Color serveAccent = Color(0xFFFFD700);

  // -- Stamina bars (M1-026) -------------------------------------------------

  /// Normal stamina fill — bright green, clearly readable against the dark
  /// background, communicates a healthy stamina state at a glance.
  static const Color staminaFill = Color(0xFF4CAF50);

  /// Low-stamina fill — warm amber-red, unmistakably distinct from [staminaFill]
  /// and maps to the danger zone below the stamina debuff threshold.
  static const Color staminaLow = Color(0xFFE53935);

  /// Stamina bar border — medium grey so the bar frame reads against both the
  /// dark background and the coloured fill without distracting from play.
  static const Color staminaBarBorder = Color(0xFF888888);

  /// Stamina bar background — very dark grey, giving the bar a recessed look
  /// so the fill stands out clearly.
  static const Color staminaBarBackground = Color(0xFF222222);
}
