import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Shown while the session is being restored. It does not navigate: the
/// router sends the user onward as soon as the session resolves.
/// If this takes unusually long it offers a retry, so it is never an endless
/// spinner.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.slowAfter = const Duration(seconds: 8)});

  final Duration slowAfter;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book,
                  size: 80, color: DesignTokens.primaryDarkGreen),
              const SizedBox(height: DesignTokens.space24),
              const Text('دار تحفيظ قرآن',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: DesignTokens.mainText)),
              const SizedBox(height: DesignTokens.space40),
              if (!_slow) ...[
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: DesignTokens.space16),
                const Text('جاري التهيئة…',
                    style: TextStyle(color: DesignTokens.secondaryText)),
              ] else ...[
                const Text('يستغرق التحميل وقتًا أطول من المعتاد.',
                    style: TextStyle(color: DesignTokens.secondaryText)),
                const SizedBox(height: DesignTokens.space16),
                FilledButton(
                  onPressed: () {
                    setState(() => _slow = false);
                    _arm();
                    ref.invalidate(sessionProvider);
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
