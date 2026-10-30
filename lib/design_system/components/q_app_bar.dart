import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_center/core/theme/app_theme.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// The app bar of inner screens: emerald with the lattice behind it and a
/// rounded lower edge, matching the headers of the home screens.
class QAppBar extends AppBar {
  QAppBar({
    super.key,
    required Widget super.title,
    List<Widget>? actions,
    super.leading,
    super.bottom,
    super.automaticallyImplyLeading,
    // Accepted so call sites stay unchanged; titles always start-align.
    bool? centerTitle,
  }) : super(
          actions: actions == null
              ? null
              : [
                  for (final a in actions)
                    Builder(
                      builder: (context) => Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: const IconThemeData(color: Colors.white),
                          iconButtonTheme: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                  foregroundColor: Colors.white)),
                          filledButtonTheme:
                              FilledButtonThemeData(style: onDarkButtonStyle),
                        ),
                        child: a,
                      ),
                    ),
                ],
          centerTitle: false,
          backgroundColor: DesignTokens.primaryDarkGreen,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 60,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            fontFamily: DesignTokens.uiFont,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          flexibleSpace: const ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DesignTokens.deepGreen,
                    DesignTokens.primaryDarkGreen
                  ],
                ),
              ),
              child: SizedBox.expand(
                  child: CustomPaint(painter: LatticePainter())),
            ),
          ),
        );
}
