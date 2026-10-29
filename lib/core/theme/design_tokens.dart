import 'package:flutter/material.dart';

/// Design tokens for the Quran center visual identity.
/// Light mode first. Spacing based on multiples of 4 logical pixels.
class DesignTokens {
  // ---- Colors (semantic) ----
  static const Color primaryDarkGreen = Color(0xFF174C3C);
  static const Color deepGreen = Color(0xFF10382E);
  static const Color softMint = Color(0xFFE6F1EA);
  static const Color warmOffWhite = Color(0xFFFAF9F6);
  static const Color mainText = Color(0xFF202923);
  static const Color secondaryText = Color(0xFF6B756E);
  static const Color borders = Color(0xFFE3E7E2);
  static const Color success = Color(0xFF237A4B);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFB42318);
  static const Color informational = Color(0xFF245DB5);

  // ---- Spacing (multiples of 4) ----
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // ---- Border radius ----
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusFull = 24.0;

  // ---- Elevation ----
  static const double elevationLow = 1.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // ---- Component heights ----
  static const double touchTarget = 48.0;
  static const double buttonHeight = 52.0;
  static const double fieldHeight = 52.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 72.0;

  // ---- Animation duration ----
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
}
