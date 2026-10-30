import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';

Color gradeColor(WirdGrade g) => switch (g) {
      WirdGrade.excellent => DesignTokens.success,
      WirdGrade.veryGood => DesignTokens.primaryDarkGreen,
      WirdGrade.good => DesignTokens.informational,
      WirdGrade.acceptable => DesignTokens.warning,
      WirdGrade.repeat => DesignTokens.error,
    };

/// A student's level at a glance: the overall word, how many wirds it rests
/// on, the trend, and how many of each mark. The wording is always tied to the
/// marks teachers gave; with no marks yet it says so instead of showing a level.
class LevelSummary extends StatelessWidget {
  const LevelSummary({super.key, required this.level, this.compact = false});

  final WirdLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!level.hasData) {
      return const Text('لا يوجد مستوى بعد: لم تُسجَّل أوراد مُقيَّمة.',
          style: TextStyle(color: DesignTokens.secondaryText));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المستوى: ${level.label} (${level.average!.toStringAsFixed(1)} من 5)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          'من آخر ${level.total} أوراد • ${trendLabel(level.trend)}',
          style: const TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
        ),
        if (!compact) ...[
          const SizedBox(height: DesignTokens.space4),
          Wrap(
            spacing: DesignTokens.space8,
            children: [
              for (final g in WirdGrade.values)
                if ((level.counts[g] ?? 0) > 0)
                  Text('${g.label} ${level.counts[g]}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: gradeColor(g))),
            ],
          ),
          for (final e in level.byType.entries)
            Text('${wirdTypeLabel(e.key)}: ${e.value.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12, color: DesignTokens.secondaryText)),
        ],
      ],
    );
  }
}
