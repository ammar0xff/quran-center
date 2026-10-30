import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/memorization_record.dart';

enum Trend { improving, steady, declining, unknown }

/// How a student is doing, summed up from the marks teachers gave their wirds.
///
/// Rules (also stated on screen):
/// * only graded wirds count (the "new assignment" has no mark);
/// * the LATEST [maxRecords] graded wirds are used, whichever teacher heard them;
/// * the average maps ممتاز..إعادة to 5..1 and is named back with the same words;
/// * a trend needs at least [minForTrend] wirds and compares the newer half
///   with the older half (a difference of half a mark or more).
/// No wirds means no level (never a made-up one).
class WirdLevel {
  const WirdLevel({
    required this.total,
    required this.counts,
    required this.average,
    required this.byType,
    required this.trend,
    required this.lastHeard,
  });

  final int total;
  final Map<WirdGrade, int> counts;
  final double? average;
  final Map<AssessmentType, double> byType;
  final Trend trend;
  final DateTime? lastHeard;

  bool get hasData => total > 0;

  String? get label {
    final a = average;
    if (a == null) return null;
    if (a >= 4.5) return 'ممتاز';
    if (a >= 3.5) return 'جيد جدًا';
    if (a >= 2.5) return 'جيد';
    if (a >= 1.5) return 'مقبول';
    return 'يحتاج إعادة';
  }
}

const maxRecords = 12;
const minForTrend = 6;

const gradedTypes = {
  AssessmentType.newMemorization,
  AssessmentType.recentRevision,
  AssessmentType.longTermRevision,
  AssessmentType.generalRecitation,
};

WirdLevel computeLevel(Iterable<MemorizationRecord> records) {
  final graded = records
      .where((r) => r.grade != null && gradedTypes.contains(r.assessmentType))
      .toList()
    ..sort((a, b) => b.assessedAt.compareTo(a.assessedAt)); // newest first
  final used = graded.take(maxRecords).toList();

  final counts = {for (final g in WirdGrade.values) g: 0};
  for (final r in used) {
    counts[r.grade!] = counts[r.grade!]! + 1;
  }

  double? mean(Iterable<MemorizationRecord> rs) => rs.isEmpty
      ? null
      : rs.map((r) => r.grade!.score).reduce((a, b) => a + b) / rs.length;

  final byType = <AssessmentType, double>{};
  for (final t in gradedTypes) {
    final m = mean(used.where((r) => r.assessmentType == t));
    if (m != null) byType[t] = m;
  }

  var trend = Trend.unknown;
  if (used.length >= minForTrend) {
    final half = used.length ~/ 2;
    final newer = mean(used.take(half))!;
    final older = mean(used.skip(used.length - half))!;
    final diff = newer - older;
    trend = diff >= 0.5
        ? Trend.improving
        : diff <= -0.5
            ? Trend.declining
            : Trend.steady;
  }

  return WirdLevel(
    total: used.length,
    counts: counts,
    average: mean(used),
    byType: byType,
    trend: trend,
    lastHeard: used.isEmpty ? null : used.first.assessedAt,
  );
}

String trendLabel(Trend t) => switch (t) {
      Trend.improving => 'في تحسّن',
      Trend.steady => 'مستقر',
      Trend.declining => 'في تراجع',
      Trend.unknown => 'لا يكفي للمقارنة بعد',
    };

String wirdTypeLabel(AssessmentType t) => switch (t) {
      AssessmentType.newMemorization => 'ورد الحفظ',
      AssessmentType.recentRevision => 'مراجعة: ماضي قريب',
      AssessmentType.longTermRevision => 'مراجعة: ماضي بعيد',
      AssessmentType.generalRecitation => 'تلاوة عامة',
      AssessmentType.newAssignment => 'الجديد',
    };
