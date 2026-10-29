import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_center/app/router.dart';
import 'package:quran_center/core/localization/app_localizations.dart';
import 'package:quran_center/core/theme/app_theme.dart';

/// Root widget. Holds the Riverpod scope, MaterialApp, theme, localization, router.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'دار تحفيظ قرآن',
      debugShowCheckedModeBanner: false,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),
      routerConfig: router,
      builder: (context, child) {
        // Global error boundary could wrap child here.
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
