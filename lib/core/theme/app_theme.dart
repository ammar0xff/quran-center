import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Light theme (primary). Dark theme deferred per spec.
final ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: DesignTokens.primaryDarkGreen,
    secondary: DesignTokens.deepGreen,
    surface: DesignTokens.warmOffWhite,
    onPrimary: Colors.white,
    onSurface: DesignTokens.mainText,
    error: DesignTokens.error,
  ),
  scaffoldBackgroundColor: DesignTokens.warmOffWhite,
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: DesignTokens.elevationLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      side: const BorderSide(color: DesignTokens.borders),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      borderSide: const BorderSide(color: DesignTokens.borders),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      borderSide: const BorderSide(color: DesignTokens.borders),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      borderSide: const BorderSide(color: DesignTokens.primaryDarkGreen, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: DesignTokens.space16,
      vertical: DesignTokens.space12,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DesignTokens.primaryDarkGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      ),
      elevation: 0,
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: DesignTokens.mainText,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: DesignTokens.mainText,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: DesignTokens.mainText,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: DesignTokens.mainText,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: DesignTokens.mainText,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: DesignTokens.secondaryText,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: DesignTokens.mainText,
    ),
  ),
  iconTheme: const IconThemeData(
    color: DesignTokens.secondaryText,
    size: 24,
  ),
);

/// Dark theme placeholder (deferred; structure only).
final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DesignTokens.deepGreen,
);
