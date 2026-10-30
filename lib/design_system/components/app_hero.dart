import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// The deep-emerald header with the lattice behind it. Sits at the top of the
/// home screens and extends under the status bar.
class AppHero extends StatelessWidget {
  const AppHero({super.key, required this.child, this.bottomRadius = 32});

  final Widget child;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DesignTokens.deepGreen, DesignTokens.primaryDarkGreen],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: LatticePainter())),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A translucent tile on the hero: a small label above a value.
class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.label, required this.value, this.leading, this.onTap});

  final String label;
  final Widget value;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 12, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        child: value,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
