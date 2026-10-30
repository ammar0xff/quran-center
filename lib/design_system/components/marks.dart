import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/design_system/components/rosette.dart';

Color gradeColor(WirdGrade g) => switch (g) {
      WirdGrade.excellent => DesignTokens.gradeExcellent,
      WirdGrade.veryGood => DesignTokens.gradeVeryGood,
      WirdGrade.good => DesignTokens.gradeGood,
      WirdGrade.acceptable => DesignTokens.gradeAcceptable,
      WirdGrade.repeat => DesignTokens.gradeRepeat,
    };

/// Colour for an average mark (1-5), so a level badge matches its word.
Color levelColor(double average) {
  if (average >= 4.5) return DesignTokens.gradeExcellent;
  if (average >= 3.5) return DesignTokens.gradeVeryGood;
  if (average >= 2.5) return DesignTokens.gradeGood;
  if (average >= 1.5) return DesignTokens.gradeAcceptable;
  return DesignTokens.gradeRepeat;
}

/// A mark as a pill: always the word, tinted with its colour.
class GradeChip extends StatelessWidget {
  const GradeChip(this.grade, {super.key, this.large = false});
  final WirdGrade grade;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = gradeColor(grade);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(grade.label,
          style: TextStyle(
              color: Color.lerp(c, Colors.black, 0.25),
              fontWeight: FontWeight.w700,
              fontSize: large ? 15 : 12.5)),
    );
  }
}

/// A student's level as a rosette in the colour of its word.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 56, this.onDark = false});
  final WirdLevel level;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final a = level.average;
    if (a == null) {
      return Rosette(
        size: size,
        color: onDark ? Colors.white54 : DesignTokens.bordersStrong,
        filled: false,
        child: Icon(Icons.remove, size: size * 0.4, color: onDark ? Colors.white70 : DesignTokens.secondaryText),
      );
    }
    return Rosette(
      size: size,
      color: levelColor(a),
      child: Text(a.toStringAsFixed(1),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.3)),
    );
  }
}

/// Section heading: a title with an optional gold rule, never a number.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(color: DesignTokens.gold, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DesignTokens.mainText)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
