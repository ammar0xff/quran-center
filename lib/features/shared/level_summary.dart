import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/design_system/components/marks.dart';

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
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المستوى: ${level.label} (${level.average!.toStringAsFixed(1)} من 5)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          'من آخر ${level.total} أوراد • ${trendLabel(level.trend)}',
          style:
              const TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
        ),
        if (!compact) ...[
          const SizedBox(height: DesignTokens.space8),
          Wrap(
            spacing: DesignTokens.space8,
            runSpacing: 4,
            children: [
              for (final g in WirdGrade.values)
                if ((level.counts[g] ?? 0) > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: gradeColor(g).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${g.label} ${level.counts[g]}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                Color.lerp(gradeColor(g), Colors.black, 0.25))),
                  ),
            ],
          ),
          const SizedBox(height: DesignTokens.space4),
          for (final e in level.byType.entries)
            Text('${wirdTypeLabel(e.key)}: ${e.value.toStringAsFixed(1)}',
                style: const TextStyle(
                    fontSize: 12, color: DesignTokens.secondaryText)),
        ],
      ],
    );
    if (compact) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LevelBadge(level: level, size: 60),
        const SizedBox(width: 14),
        Expanded(child: text),
      ],
    );
  }
}
