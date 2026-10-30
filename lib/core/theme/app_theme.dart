import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

const _edge = 4.0; // depth of the pressed edge on buttons

/// Chunky, tactile buttons: a flat face on a darker edge that sinks when
/// pressed. Built with a background builder so every existing button gets it.
Widget _chunky(
  Set<WidgetState> states,
  Widget? child, {
  required Color face,
  required Color edge,
  required Color disabledFace,
  required Color disabledEdge,
  Color? border,
}) {
  final disabled = states.contains(WidgetState.disabled);
  final pressed = states.contains(WidgetState.pressed);
  final f = disabled ? disabledFace : face;
  final e = disabled ? disabledEdge : edge;
  final down = pressed && !disabled;
  return Padding(
    padding: const EdgeInsets.only(bottom: _edge),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      transform: Matrix4.translationValues(0, down ? _edge - 1 : 0, 0),
      decoration: BoxDecoration(
        color: f,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: border == null ? null : Border.all(color: border, width: 2),
        boxShadow: [BoxShadow(color: e, offset: Offset(0, down ? 1 : _edge))],
      ),
      child: child,
    ),
  );
}

TextStyle _label(Color c) => TextStyle(
      fontFamily: DesignTokens.uiFont,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: c,
      height: 1.2,
    );

final _filledStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, DesignTokens.buttonHeight - _edge)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
  elevation: const WidgetStatePropertyAll(0),
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? const Color(0xFF8FA096) : Colors.white),
  textStyle: WidgetStatePropertyAll(_label(Colors.white)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMedium)).asProperty,
  backgroundBuilder: (context, states, child) => _chunky(
    states,
    child,
    face: DesignTokens.leaf,
    edge: DesignTokens.leafEdge,
    disabledFace: const Color(0xFFE3EAE5),
    disabledEdge: const Color(0xFFD2DCD5),
  ),
);

final _outlinedStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, DesignTokens.buttonHeight - _edge)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
  elevation: const WidgetStatePropertyAll(0),
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  side: const WidgetStatePropertyAll(BorderSide.none),
  foregroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? const Color(0xFF9AA9A0) : DesignTokens.primaryDarkGreen),
  textStyle: WidgetStatePropertyAll(_label(DesignTokens.primaryDarkGreen)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMedium)).asProperty,
  backgroundBuilder: (context, states, child) => _chunky(
    states,
    child,
    face: Colors.white,
    edge: DesignTokens.bordersStrong,
    disabledFace: Colors.white,
    disabledEdge: DesignTokens.borders,
    border: DesignTokens.bordersStrong,
  ),
);

extension on OutlinedBorder {
  WidgetStateProperty<OutlinedBorder> get asProperty => WidgetStatePropertyAll(this);
}

TextTheme _textTheme() {
  TextStyle t(double size, FontWeight w, {Color c = DesignTokens.mainText, double h = 1.4}) => TextStyle(
        fontFamily: DesignTokens.uiFont,
        fontSize: size,
        fontWeight: w,
        color: c,
        height: h,
      );
  return TextTheme(
    displayLarge: t(34, FontWeight.w700, h: 1.25),
    displayMedium: t(28, FontWeight.w700, h: 1.25),
    headlineMedium: t(22, FontWeight.w700, h: 1.3),
    titleLarge: t(18, FontWeight.w700),
    titleMedium: t(16, FontWeight.w600),
    bodyLarge: t(16, FontWeight.w400, h: 1.55),
    bodyMedium: t(14, FontWeight.w400, c: DesignTokens.secondaryText, h: 1.5),
    bodySmall: t(12, FontWeight.w400, c: DesignTokens.secondaryText),
    labelLarge: t(14, FontWeight.w600),
  );
}

OutlineInputBorder _field(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      borderSide: BorderSide(color: c, width: w),
    );

/// Light theme (primary). Dark theme is deferred.
final ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: DesignTokens.uiFont,
  colorScheme: ColorScheme.fromSeed(
    seedColor: DesignTokens.primaryDarkGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: DesignTokens.primaryDarkGreen,
    onPrimary: Colors.white,
    secondary: DesignTokens.gold,
    surface: DesignTokens.surface,
    onSurface: DesignTokens.mainText,
    error: DesignTokens.error,
    outline: DesignTokens.bordersStrong,
  ),
  scaffoldBackgroundColor: DesignTokens.warmOffWhite,
  textTheme: _textTheme(),
  splashFactory: InkRipple.splashFactory,
  appBarTheme: AppBarTheme(
    backgroundColor: DesignTokens.warmOffWhite,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: DesignTokens.mainText,
    titleTextStyle: _textTheme().titleLarge,
  ),
  cardTheme: CardThemeData(
    color: DesignTokens.surface,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 5),
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
      side: const BorderSide(color: DesignTokens.borders, width: 1.5),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    titleTextStyle: TextStyle(
        fontFamily: DesignTokens.uiFont, fontSize: 15, fontWeight: FontWeight.w600, color: DesignTokens.mainText),
    subtitleTextStyle: TextStyle(
        fontFamily: DesignTokens.uiFont, fontSize: 13, color: DesignTokens.secondaryText, height: 1.5),
  ),
  dividerTheme: const DividerThemeData(color: DesignTokens.borders, thickness: 1, space: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: _field(DesignTokens.bordersStrong),
    enabledBorder: _field(DesignTokens.bordersStrong),
    focusedBorder: _field(DesignTokens.primaryDarkGreen, 2),
    errorBorder: _field(DesignTokens.error),
    focusedErrorBorder: _field(DesignTokens.error, 2),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: DesignTokens.secondaryText),
    floatingLabelStyle: const TextStyle(color: DesignTokens.primaryDarkGreen, fontWeight: FontWeight.w600),
  ),
  filledButtonTheme: FilledButtonThemeData(style: _filledStyle),
  elevatedButtonTheme: ElevatedButtonThemeData(style: _filledStyle),
  outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedStyle),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: DesignTokens.primaryDarkGreen,
      textStyle: _label(DesignTokens.primaryDarkGreen).copyWith(fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusSmall)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: DesignTokens.softMint,
    side: const BorderSide(color: DesignTokens.bordersStrong, width: 1.5),
    labelStyle: const TextStyle(
        fontFamily: DesignTokens.uiFont, fontSize: 14, fontWeight: FontWeight.w600, color: DesignTokens.mainText),
    secondaryLabelStyle: const TextStyle(
        fontFamily: DesignTokens.uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: DesignTokens.primaryDarkGreen),
    checkmarkColor: DesignTokens.primaryDarkGreen,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMedium)),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    showCheckmark: false,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: DesignTokens.primaryDarkGreen,
    unselectedLabelColor: DesignTokens.secondaryText,
    indicatorColor: DesignTokens.primaryDarkGreen,
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: DesignTokens.borders,
    labelStyle: TextStyle(fontFamily: DesignTokens.uiFont, fontSize: 14, fontWeight: FontWeight.w700),
    unselectedLabelStyle: TextStyle(fontFamily: DesignTokens.uiFont, fontSize: 14, fontWeight: FontWeight.w500),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusFull)),
    titleTextStyle: _textTheme().titleLarge,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMedium)),
    contentTextStyle: const TextStyle(
        fontFamily: DesignTokens.uiFont, fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF9AA9A0)),
    trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? DesignTokens.leaf : const Color(0xFFE3EAE5)),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: DesignTokens.leaf,
    linearTrackColor: Color(0xFFE3EAE5),
    linearMinHeight: 10,
  ),
  iconTheme: const IconThemeData(color: DesignTokens.secondaryText, size: 24),
);

/// Dark theme placeholder (deferred; structure only).
final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DesignTokens.deepGreen,
);
