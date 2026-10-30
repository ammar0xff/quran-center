import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/memorization_record.dart';

int _n = 0;
MemorizationRecord _r(WirdGrade? g, int daysAgo,
    {AssessmentType type = AssessmentType.newMemorization, String teacher = 't1'}) {
  final at = DateTime(2026, 11, 30).subtract(Duration(days: daysAgo));
  return MemorizationRecord(
      recordId: 'r${_n++}', centerId: 'c', studentId: 's', teacherId: teacher,
      assessmentType: type, schemaVersion: 1, surah: 1, startAyah: 1, endAyah: 2,
      criteriaScores: const {}, mistakesCount: 0, requiresFollowUp: false, grade: g,
      assessedAt: at, createdAt: at, updatedAt: at);
}

void main() {
  test('no wirds means no level, not a made-up one', () {
    final l = computeLevel([]);
    expect(l.hasData, isFalse);
    expect(l.average, isNull);
    expect(l.label, isNull);
    expect(l.lastHeard, isNull);
    expect(l.trend, Trend.unknown);
  });

  test('the five marks map to 5..1 and the average is named with the same words', () {
    expect(WirdGrade.values.map((g) => g.score), [5, 4, 3, 2, 1]);
    expect(WirdGrade.values.map((g) => g.label), ['ممتاز', 'جيد جدًا', 'جيد', 'مقبول', 'إعادة']);
    String? label(List<WirdGrade> gs) =>
        computeLevel([for (var i = 0; i < gs.length; i++) _r(gs[i], i)]).label;
    expect(label([WirdGrade.excellent, WirdGrade.excellent]), 'ممتاز');
    expect(label([WirdGrade.excellent, WirdGrade.veryGood]), 'ممتاز'); // 4.5
    expect(label([WirdGrade.veryGood, WirdGrade.good]), 'جيد جدًا'); // 3.5
    expect(label([WirdGrade.good, WirdGrade.acceptable]), 'جيد'); // 2.5
    expect(label([WirdGrade.acceptable, WirdGrade.repeat]), 'مقبول'); // 1.5
    expect(label([WirdGrade.repeat]), 'يحتاج إعادة');
  });

  test('the new assignment and ungraded records are ignored', () {
    final l = computeLevel([
      _r(null, 1, type: AssessmentType.newAssignment),
      _r(null, 2),
      _r(WirdGrade.good, 3),
    ]);
    expect(l.total, 1);
    expect(l.average, 3);
  });

  test('only the latest 12 count, whichever teacher heard them', () {
    final recs = [
      for (var i = 0; i < 12; i++) _r(WirdGrade.excellent, i, teacher: i.isEven ? 't1' : 'visitor'),
      for (var i = 12; i < 20; i++) _r(WirdGrade.repeat, i), // older and poorer: outside the window
    ];
    final l = computeLevel(recs);
    expect(l.total, 12);
    expect(l.average, 5);
    expect(l.counts[WirdGrade.repeat], 0);
  });

  test('averages are kept per kind of wird', () {
    final l = computeLevel([
      _r(WirdGrade.excellent, 1),
      _r(WirdGrade.good, 2, type: AssessmentType.recentRevision),
      _r(WirdGrade.acceptable, 3, type: AssessmentType.longTermRevision),
      _r(WirdGrade.repeat, 4, type: AssessmentType.longTermRevision),
    ]);
    expect(l.byType[AssessmentType.newMemorization], 5);
    expect(l.byType[AssessmentType.recentRevision], 3);
    expect(l.byType[AssessmentType.longTermRevision], 1.5);
    expect(l.counts[WirdGrade.repeat], 1);
  });

  group('trend', () {
    List<MemorizationRecord> series(List<WirdGrade> newestFirst) =>
        [for (var i = 0; i < newestFirst.length; i++) _r(newestFirst[i], i)];

    test('needs at least 6 wirds', () {
      expect(computeLevel(series(List.filled(5, WirdGrade.good))).trend, Trend.unknown);
    });
    test('newer half clearly better -> improving; clearly worse -> declining; else steady', () {
      const hi = WirdGrade.excellent, lo = WirdGrade.acceptable;
      expect(computeLevel(series([hi, hi, hi, lo, lo, lo])).trend, Trend.improving);
      expect(computeLevel(series([lo, lo, lo, hi, hi, hi])).trend, Trend.declining);
      expect(computeLevel(series(List.filled(6, WirdGrade.good))).trend, Trend.steady);
    });
  });

  test('last heard is the newest graded wird', () {
    final l = computeLevel([_r(WirdGrade.good, 9), _r(WirdGrade.good, 2), _r(null, 0)]);
    expect(l.lastHeard, DateTime(2026, 11, 28));
  });

  test('labels exist for every kind of wird and trend', () {
    expect(AssessmentType.values.map(wirdTypeLabel).toSet(), hasLength(AssessmentType.values.length));
    expect(Trend.values.map(trendLabel).toSet(), hasLength(Trend.values.length));
  });
}
