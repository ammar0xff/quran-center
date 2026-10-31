import 'package:flutter/material.dart';

/// Visual identity of the center.
///
/// Emerald and a pale cool page, taken from the green of a mushaf cover; gold
/// is rationed to surah names and rosettes. Marks use a five-step ramp that is
/// always accompanied by its word, never colour alone.
class DesignTokens {
  // ---- Brand ----
  static const Color primaryDarkGreen = Color(0xFF0E5A47); // emerald
  static const Color emerald = primaryDarkGreen;
  static const Color deepGreen = Color(0xFF0A3A30); // night
  static const Color leaf = Color(0xFF168A57); // button face
  static const Color leafEdge = Color(0xFF0F6A41); // button pressed edge
  static const Color softMint = Color(0xFFE3F1E9);
  static const Color gold = Color(0xFFB8893B); // surah names, rosettes
  static const Color goldSoft = Color(0xFFF5ECD6);

  // ---- Surfaces & text ----
  static const Color warmOffWhite = Color(0xFFF3F6F2); // page
  static const Color surface = Colors.white;
  static const Color mainText = Color(0xFF14211C);
  static const Color secondaryText = Color(0xFF5F6F66);
  static const Color borders = Color(0xFFDDE6DF);
  static const Color border = borders;
  static const Color bordersStrong = Color(0xFFC9D6CC);

  // ---- Status ----
  static const Color success = Color(0xFF1E9E63);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFCF4B3F);
  static const Color informational = Color(0xFF2B6CB0);

  // ---- Marks: ممتاز … إعادة ----
  static const Color gradeExcellent = Color(0xFF1E9E63);
  static const Color gradeVeryGood = Color(0xFF6BA43A);
  static const Color gradeGood = Color(0xFFD9A21B);
  static const Color gradeAcceptable = Color(0xFFE07B2A);
  static const Color gradeRepeat = Color(0xFFCF4B3F);

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

  // ---- Radius ----
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusFull = 28.0;

  // ---- Elevation (cards are flat with a border; only sheets float) ----
  static const double elevationLow = 0.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 8.0;

  // ---- Component heights ----
  static const double touchTarget = 48.0;
  static const double buttonHeight = 54.0;
  static const double fieldHeight = 52.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 72.0;

  // ---- Type families ----
  static const String uiFont = 'PlexArabic';
  static const String nameFont = 'Amiri';

  // ---- Animation ----
  static const Duration durationFast = Duration(milliseconds: 160);
  static const Duration durationNormal = Duration(milliseconds: 280);
}
