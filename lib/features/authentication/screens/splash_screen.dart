import 'package:flutter/material.dart';
import 'package:quran_center/app/router.dart';
import 'package:quran_center/core/localization/app_localizations.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Splash screen: initializes Firebase, restores session, resolves role,
/// then navigates to login or the authorized dashboard.
/// States: initializing, retry, config error. Never infinite spinner.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // branded pause
      // Firebase is initialized in bootstrap(); here we resolve role and route.
      if (!mounted) return;
      // TODO: wire appLifecycleProvider role resolution here.
      _navigate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Config error';
      });
    }
  }

  void _navigate() {
    // Until auth is wired, route to login.
    Navigator.of(context).pushReplacementNamed(AppRoute.login);
  }

  void _retry() {
    setState(() {
      _initializing = true;
      _error = null;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book, size: 80, color: DesignTokens.primaryDarkGreen),
              const SizedBox(height: DesignTokens.space24),
              Text(
                l10n.s('appNameAr'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.mainText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                l10n.s('appName'),
                style: TextStyle(
                  fontSize: 16,
                  color: DesignTokens.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space40),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: DesignTokens.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space16),
                FilledButton.tonal(
                  onPressed: _retry,
                  child: Text(l10n.s('splashRetry')),
                ),
              ] else if (_initializing) ...[
                const SizedBox(
                  height: DesignTokens.touchTarget,
                  width: DesignTokens.touchTarget,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(DesignTokens.primaryDarkGreen),
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                Text(
                  l10n.s('splashLoading'),
                  style: TextStyle(color: DesignTokens.secondaryText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
