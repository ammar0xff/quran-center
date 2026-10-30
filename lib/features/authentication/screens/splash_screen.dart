import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/app_theme.dart' show onDarkButtonStyle;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

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
        backgroundColor: DesignTokens.deepGreen,
        body: Stack(
          children: [
            const Positioned.fill(
                child: CustomPaint(painter: LatticePainter())),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Rosette(
                    size: 96,
                    color: DesignTokens.gold,
                    child: Icon(Icons.menu_book_rounded,
                        size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: DesignTokens.space24),
                  const Text('بسم الله الرحمن الرحيم',
                      style: TextStyle(
                          fontFamily: DesignTokens.nameFont,
                          fontSize: 28,
                          color: Color(0xFFE9CF93))),
                  const SizedBox(height: 6),
                  const Text('دار تحفيظ قرآن',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: DesignTokens.space40),
                  if (!_slow) ...[
                    const CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                    const SizedBox(height: DesignTokens.space16),
                    const Text('جاري التهيئة…',
                        style: TextStyle(color: Color(0xB3FFFFFF))),
                  ] else ...[
                    const Text('يستغرق التحميل وقتًا أطول من المعتاد.',
                        style: TextStyle(color: Color(0xB3FFFFFF))),
                    const SizedBox(height: DesignTokens.space16),
                    FilledButton(
                      style: onDarkButtonStyle,
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
          ],
        ),
      ),
    );
  }
}
