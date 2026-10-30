import 'package:quran_center/core/quran/surahs.dart';

/// The rubric used by assessments (schema version [assessmentSchemaVersion]).
/// Stored records keep the version they were written with, so they stay
/// interpretable if the rubric changes later.
const assessmentSchemaVersion = 1;

class AssessmentCriterion {
  const AssessmentCriterion(this.id, this.label);
  final String id;
  final String label;
}

const assessmentCriteria = <AssessmentCriterion>[
  AssessmentCriterion('accuracy', 'الدقة'),
  AssessmentCriterion('tajweed', 'التجويد'),
  AssessmentCriterion('fluency', 'الطلاقة'),
  AssessmentCriterion('pronunciation', 'مخارج الحروف'),
  AssessmentCriterion('independence', 'الاستقلالية'),
];

const criterionMinScore = 1;
const criterionMaxScore = 5;
const maxMistakes = 1000;

class AssessmentErrors {
  const AssessmentErrors({this.surah, this.range, this.mistakes, this.scores});

  final String? surah;
  final String? range;
  final String? mistakes;
  final String? scores;

  bool get hasErrors =>
      surah != null || range != null || mistakes != null || scores != null;
}

/// Validates an assessment form. Criteria are optional; each one given must be
/// a whole score from [criterionMinScore] to [criterionMaxScore] and must be a
/// known criterion. Nothing is ever auto-graded or marked as mastered.
AssessmentErrors validateAssessment({
  required int? surah,
  required String startAyah,
  required String endAyah,
  required String mistakes,
  required Map<String, int> scores,
}) {
  String? surahError;
  String? rangeError;
  if (surah == null || surahByNumber(surah) == null) {
    surahError = 'اختر السورة';
  } else {
    final start = int.tryParse(startAyah.trim());
    final end = int.tryParse(endAyah.trim());
    if (start == null || end == null) {
      rangeError = 'أدخل رقمي آية البداية والنهاية';
    } else {
      rangeError = validateAyahRange(surah, start, end);
    }
  }

  String? mistakesError;
  final m = int.tryParse(mistakes.trim());
  if (m == null) {
    mistakesError = 'أدخل عدد الأخطاء (0 إن لم يوجد)';
  } else if (m < 0 || m > maxMistakes) {
    mistakesError = 'عدد الأخطاء بين 0 و $maxMistakes';
  }

  String? scoresError;
  final known = assessmentCriteria.map((c) => c.id).toSet();
  for (final e in scores.entries) {
    if (!known.contains(e.key) ||
        e.value < criterionMinScore ||
        e.value > criterionMaxScore) {
      scoresError = 'درجة المعيار بين $criterionMinScore و $criterionMaxScore';
      break;
    }
  }

  return AssessmentErrors(
    surah: surahError,
    range: rangeError,
    mistakes: mistakesError,
    scores: scoresError,
  );
}
