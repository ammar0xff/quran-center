import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Section header used on dashboards.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'عرض الكل',
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: DesignTokens.space20,
        right: DesignTokens.space20,
        top: DesignTokens.space24,
        bottom: DesignTokens.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.mainText,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: DesignTokens.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                seeAllLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: DesignTokens.primaryDarkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
