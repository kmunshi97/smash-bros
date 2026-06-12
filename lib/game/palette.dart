import 'package:flutter/painting.dart';

// ---------------------------------------------------------------------------
// Game render palette (M1-022..024, reskinned M1-027)
//
// Single source-of-truth for every colour used by the Flame components.
// Stadium/cartoon look inspired by Head Ball 2: sky blue arena, green pitch,
// orange-gold buttons, dark scoreboard with LED-green digits.
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

  /// Sky top colour — deep azure blue at the top of the gradient.
  static const Color skyTop = Color(0xFF1A6FBF);

  /// Sky bottom colour — lighter cornflower blue at the arena horizon.
  static const Color skyBottom = Color(0xFF5BB8F5);

  /// Deep-space background fill (kept for compatibility with the phase banner
  /// component's backdrop); matches the dark arena tone.
  static const Color background = Color(0xFF0D2B45);

  // -- Grandstand & Crowd -----------------------------------------------------

  /// Upper grandstand tier fill — medium stadium grey.
  static const Color standUpperFill = Color(0xFF8C8C9A);

  /// Lower grandstand tier fill — slightly warmer grey.
  static const Color standLowerFill = Color(0xFF7A7A87);

  /// Grandstand structural divider — dark border between tiers.
  static const Color standDivider = Color(0xFF4A4A55);

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

  // -- Floodlights ------------------------------------------------------------

  /// Dark panel behind floodlight banks.
  static const Color floodlightPanel = Color(0xFF2B2B35);

  /// Individual floodlight bulb circles — light grey suggesting bright lamps.
  static const Color floodlightBulb = Color(0xFFCCCCD8);

  // -- Advertising strip ------------------------------------------------------

  /// Light base tone for the advertising hoarding strip.
  static const Color adStripBase = Color(0xFFEEEECC);

  /// Alternate ad board tile — slightly darker cream.
  static const Color adStripAlt = Color(0xFFD4D4AA);

  // -- Pitch & Court floor ----------------------------------------------------

  /// Base pitch green — the primary ground-band colour.
  static const Color pitchBase = Color(0xFF2E7D32);

  /// Alternate mowing stripe — slightly lighter to suggest mown grass stripes.
  static const Color pitchStripe = Color(0xFF388E3C);

  /// Arena / play-space tone above the pitch — dark teal, keeps the air
  /// readable against the shuttle and players.
  static const Color arenaField = Color(0xFF0D3A5C);

  /// Court floor colour — kept as alias to [pitchBase] for compatibility.
  static const Color courtFloor = pitchBase;

  /// White court-boundary and service-line markings.
  static const Color courtLines = Color(0xFFFFFFFF);

  // -- Dirt apron (controls zone) ---------------------------------------------

  /// Warm brown base of the dirt apron below the pitch where controls sit.
  static const Color dirtApronBase = Color(0xFF8D6E63);

  /// Slightly darker dirt apron shadow at the very bottom.
  static const Color dirtApronDark = Color(0xFF6D4C41);

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
