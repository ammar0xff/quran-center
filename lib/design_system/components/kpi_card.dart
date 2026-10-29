import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Premium summary/KPI card.
///
/// [value] is the main number, [label] the description, [trend] an optional
/// small delta indicator (e.g. "+12% vs last week"), [icon] the leading icon,
/// [onTap] opens the corresponding filtered detail screen.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    this.trend,
    this.icon,
    this.onTap,
    this.color,
  });

  final String value;
  final String label;
  final String? trend;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? DesignTokens.primaryDarkGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(color: DesignTokens.borders),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: DesignTokens.space12),
                  ],
                  const Spacer(),
                  if (trend != null)
                    Text(
                      trend!,
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.space16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.mainText,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.secondaryText,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
