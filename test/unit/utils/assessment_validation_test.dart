import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/assessment_validation.dart';

AssessmentErrors _v({
  int? surah = 2,
  String start = '1',
  String end = '5',
  String mistakes = '0',
  Map<String, int> scores = const {},
}) =>
    validateAssessment(
        surah: surah, startAyah: start, endAyah: end, mistakes: mistakes, scores: scores);

void main() {
  test('a minimal valid assessment has no errors; criteria are optional', () {
    expect(_v().hasErrors, isFalse);
    expect(_v(scores: {'accuracy': 4, 'tajweed': 5}).hasErrors, isFalse);
  });

  test('surah is required and must exist', () {
    expect(_v(surah: null).surah, isNotNull);
    expect(_v(surah: 0).surah, isNotNull);
    expect(_v(surah: 115).surah, isNotNull);
  });

  test('ayah range is checked against the real surah length', () {
    expect(_v(surah: 1, start: '1', end: '7').range, isNull);
    expect(_v(surah: 1, start: '1', end: '8').range, isNotNull);
    expect(_v(start: '0').range, isNotNull);
    expect(_v(start: '6', end: '5').range, isNotNull);
    expect(_v(start: 'a').range, isNotNull);
    expect(_v(end: '').range, isNotNull);
    expect(_v(start: ' 3 ', end: ' 3 ').range, isNull);
  });

  test('mistakes must be a whole non-negative number', () {
    expect(_v(mistakes: '').mistakes, isNotNull);
    expect(_v(mistakes: '-1').mistakes, isNotNull);
    expect(_v(mistakes: '2.5').mistakes, isNotNull);
    expect(_v(mistakes: '${maxMistakes + 1}').mistakes, isNotNull);
    expect(_v(mistakes: '12').mistakes, isNull);
  });

  test('criteria scores are bounded and must be known criteria', () {
    expect(_v(scores: {'accuracy': 0}).scores, isNotNull);
    expect(_v(scores: {'accuracy': 6}).scores, isNotNull);
    expect(_v(scores: {'accuracy': 1}).scores, isNull);
    expect(_v(scores: {'accuracy': 5}).scores, isNull);
    expect(_v(scores: {'charisma': 3}).scores, isNotNull);
  });

  test('every problem is reported at once', () {
    final e = _v(surah: null, mistakes: 'x', scores: {'accuracy': 9});
    expect(e.surah, isNotNull);
    expect(e.mistakes, isNotNull);
    expect(e.scores, isNotNull);
  });

  test('criteria ids are unique', () {
    expect(assessmentCriteria.map((c) => c.id).toSet(), hasLength(assessmentCriteria.length));
  });
}
