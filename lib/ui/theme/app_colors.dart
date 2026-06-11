import 'package:flutter/material.dart';

abstract final class AppColors {
  // ------------------------------------------------------------------
  // Core palette
  // ------------------------------------------------------------------

  static const Color primary = Color(0xFF7289DA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF99AAB5);
  static const Color dark = Color(0xFF2C2F33);
  static const Color darker = Color(0xFF23272A);

  // ------------------------------------------------------------------
  // Semantic aliases
  // ------------------------------------------------------------------

  static const Color background = darker;
  static const Color surface = dark;
  static const Color textPrimary = white;
  static const Color textSecondary = grey;
  static const Color accent = primary;
  static const Color divider = Color(0xFF3A3D42);

  // ------------------------------------------------------------------
  // Game-specific
  // ------------------------------------------------------------------

  static const Color player1 = Color(0xFF4A90D9);
  static const Color player2 = Color(0xFFD94A4A);
  static const Color shuttle = white;
  static const Color court = Color(0xFF2D5A27);
  static const Color courtLines = white;
  static const Color net = Color(0xFF444444);

  // ------------------------------------------------------------------
  // Feedback
  // ------------------------------------------------------------------

  static const Color success = Color(0xFF43B581);
  static const Color warning = Color(0xFFFAA61A);
  static const Color error = Color(0xFFF04747);
  static const Color info = primary;

  // ------------------------------------------------------------------
  // Stamina bar gradient
  // ------------------------------------------------------------------

  static const Color staminaFull = Color(0xFF43B581);
  static const Color staminaLow = Color(0xFFFAA61A);
  static const Color staminaCritical = Color(0xFFF04747);

  // ------------------------------------------------------------------
  // Material ColorScheme helper
  // ------------------------------------------------------------------

  static ColorScheme get colorScheme => const ColorScheme.dark(
    primary: primary,
    onPrimary: white,
    secondary: grey,
    onSecondary: white,
    surface: surface,
    error: error,
    onError: white,
  );
}
