import 'package:flutter/painting.dart';

// ---------------------------------------------------------------------------
// Game render palette (M1-022..024, reskinned M1-027, stadium restyle)
//
// Single source-of-truth for every colour used by the Flame components.
// Stadium/cartoon look inspired by Head Ball 2: bright daylight arena,
// saturated greens, cream ad wall, grey roof fascia.
//
// Components must read colours exclusively from this class. Do NOT inline
// colour literals in component render methods — feel-tuning is a one-file
// change here.
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
  // -- Sky / Background -------------------------------------------------------

  /// Sky top colour — bright daylight sky blue at the very top.
  static const Color skyTop = Color(0xFF87CEEB);

  /// Sky bottom colour — lighter sky blue near the roof fascia.
  static const Color skyBottom = Color(0xFFB8E4F9);

  /// Deep-space background fill (kept for compatibility with the phase banner
  /// component's backdrop); matches the dark arena tone.
  static const Color background = Color(0xFF0D2B45);

  // -- Roof -------------------------------------------------------------------

  /// Roof fascia band — light grey/white front face of the stadium roof.
  static const Color roofFascia = Color(0xFFE8E8EC);

  /// Roof underside shadow — darker grey suggesting depth below the fascia.
  static const Color roofUndersideShadow = Color(0xFFB0B0BA);

  // -- Grandstand & Crowd -----------------------------------------------------

  /// Upper grandstand tier fill — medium stadium grey.
  static const Color standUpperFill = Color(0xFF9E9EAA);

  /// Lower grandstand tier fill — slightly warmer grey.
  static const Color standLowerFill = Color(0xFF888896);

  /// Grandstand structural divider — dark border between tiers.
  static const Color standDivider = Color(0xFF4A4A55);

  /// Corner wedge section fill — slightly darker diagonal stand sections at
  /// the left and right edges, suggesting the bowl curving toward the viewer.
  static const Color standCornerWedge = Color(0xFF6E6E7A);

  /// Seat block highlight — alternating red seat banks behind crowd dots.
  static const Color seatBlockRed = Color(0xFFB71C1C);

  /// Seat block highlight — alternating blue seat banks behind crowd dots.
  static const Color seatBlockBlue = Color(0xFF1565C0);

  /// A varied set of crowd shirt colours drawn from an RNG-seeded list.
  ///
  /// `dart:math` Random is allowed in `lib/game/` — the engine-purity rule
  /// covers `lib/engine/` only (CLAUDE.md § Architecture rules).
  static const List<Color> crowdColors = [
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFFB300), // amber
    Color(0xFF8E24AA), // purple
    Color(0xFFFF7043), // deep orange
    Color(0xFF00ACC1), // cyan
    Color(0xFFFFFFFF), // white
  ];

  // -- Advertising wall -------------------------------------------------------

  /// Cream/white base of the perimeter ad wall.
  static const Color adStripBase = Color(0xFFF5F5E8);

  /// Alternate ad wall panel — slightly darker cream for tiling effect.
  static const Color adStripAlt = Color(0xFFE8E8D4);

  /// Dark navy ad text colour — block-letter ad copy on the wall.
  static const Color adTextColor = Color(0xFF1A237E);

  /// Thin shadow line at the base of the ad wall where it meets the grass.
  static const Color adWallBaseShadow = Color(0xFF2E3A1E);

  // -- Pitch & Court floor ----------------------------------------------------

  /// Base pitch green — the primary mow-band colour (bright daylight green).
  static const Color pitchBase = Color(0xFF4CAF50);

  /// Alternate mowing stripe — slightly lighter bright green.
  static const Color pitchStripe = Color(0xFF66BB6A);

  /// Court floor colour — kept as alias to [pitchBase] for compatibility.
  static const Color courtFloor = pitchBase;

  /// White court-boundary and service-line markings.
  static const Color courtLines = Color(0xFFFFFFFF);

  // -- Net --------------------------------------------------------------------

  /// Net post colour — dark charcoal pillars.
  static const Color netPost = Color(0xFF333333);

  /// Net body fill — medium dark with faint mesh lines drawn over it.
  static const Color netBody = Color(0xFF555566);

  /// Net mesh line colour — slightly lighter than the body to suggest netting.
  static const Color netMesh = Color(0xFF7777AA);

  /// Net tape band — bright white/red strip at the top of the net.
  ///
  /// Kept as a separate field for compatibility (CourtComponent etc.).
  static const Color netTape = Color(0xFFEE3333);

  // -- Players ----------------------------------------------------------------

  /// Left player team colour — blue family.
  static const Color leftPlayer = Color(0xFF1565C0);

  /// Right player team colour — red family.
  static const Color rightPlayer = Color(0xFFC62828);

  /// Skin tone for the left player's big-head face.
  static const Color skinToneLeft = Color(0xFFF5CBA7);

  /// Skin tone for the right player's big-head face.
  static const Color skinToneRight = Color(0xFFD4A574);

  /// Left player headband colour — bright blue accent strip.
  static const Color headbandLeft = Color(0xFF2196F3);

  /// Right player headband colour — bright red accent strip.
  static const Color headbandRight = Color(0xFFEF5350);

  /// White base for player eye whites.
  static const Color eyeWhite = Color(0xFFFFFFFF);

  /// Dark pupil colour for player eyes.
  static const Color eyePupil = Color(0xFF1A1A1A);

  /// Dark shoe colour worn by both players.
  static const Color shoeColor = Color(0xFF212121);

  /// Stun-flash overlay colour — bright white at 70% alpha.
  ///
  /// Blended over the player every other blink-frame while stunned.
  static const Color stunFlash = Color(0xB3FFFFFF);

  /// Dizzy star colour shown arcing above the head during stun.
  static const Color dizzyStarColor = Color(0xFFFFEB3B);

  // -- Shuttle ----------------------------------------------------------------

  /// Shuttle fill colour — pure white so the cork reads clearly.
  static const Color shuttle = Color(0xFFFFFFFF);

  /// Shuttle outline stroke — dark grey outline so the white shuttle remains
  /// readable against the light cream ad wall and pale grandstand backdrop.
  static const Color shuttleOutline = Color(0xFF444444);

  /// Trail segment base colour — white with reduced alpha.
  static const Color shuttleTrail = Color(0x66FFFFFF);

  // -- Controls ---------------------------------------------------------------

  /// Button face — orange-gold, the signature Head-Ball-style button colour.
  static const Color buttonFace = Color(0xFFFF8F00);

  /// Button bevel highlight — lighter gold for the top-arc highlight.
  static const Color buttonBevel = Color(0xFFFFCC02);

  /// Button outline / border — darker orange-brown for depth.
  static const Color buttonOutline = Color(0xFFBF5700);

  /// Button glyph / label colour — dark warm brown for legibility.
  static const Color buttonGlyph = Color(0xFF4E2000);

  /// Pressed-state button face — brighter gold when held.
  static const Color buttonPressed = Color(0xFFFFD740);

  /// Accent colour for the context-sensitive serve (TOSS) button — gold.
  ///
  /// Kept as [serveAccent] for compatibility with existing component code.
  static const Color serveAccent = Color(0xFFFFD700);

  // -- Scoreboard -------------------------------------------------------------

  /// Dark scoreboard panel background — near-black.
  static const Color scoreboardPanel = Color(0xFF151B22);

  /// Score digit LED-green colour — bright arcade green.
  static const Color scoreDigit = Color(0xFF00FF6A);

  /// Scoreboard label text — light grey 'YOU' / 'CPU'.
  static const Color scoreLabel = Color(0xFFB0BEC5);

  /// Score digit inset panel — very dark, recessed behind the digit.
  static const Color scoreDigitInset = Color(0xFF0A1410);

  /// Score panel wing / decorative side accent colour.
  static const Color scorePanelAccent = Color(0xFF263238);

  // -- Stamina bars (M1-026) -------------------------------------------------

  /// Normal stamina fill — bright green, clearly readable.
  static const Color staminaFill = Color(0xFF4CAF50);

  /// Low-stamina fill — warm amber-red, danger zone indicator.
  static const Color staminaLow = Color(0xFFE53935);

  /// Stamina bar border — thin gold outline matching button style.
  static const Color staminaBarBorder = Color(0xFFFF8F00);

  /// Stamina bar background — very dark grey recessed look.
  static const Color staminaBarBackground = Color(0xFF1A1A1A);
}
