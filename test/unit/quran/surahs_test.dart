import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/quran/surahs.dart';

void main() {
  test('114 surahs, numbered in order, with the known total of 6236 ayat', () {
    expect(surahs, hasLength(114));
    for (var i = 0; i < surahs.length; i++) {
      expect(surahs[i].number, i + 1);
      expect(surahs[i].ayahCount, greaterThan(0));
    }
    expect(surahs.fold<int>(0, (a, s) => a + s.ayahCount), 6236);
  });

  test('well-known anchors', () {
    expect(surahByNumber(1)!.name, 'الفاتحة');
    expect(surahByNumber(2)!.ayahCount, 286);
    expect(surahByNumber(114)!.name, 'الناس');
    expect(surahByNumber(0), isNull);
    expect(surahByNumber(115), isNull);
  });

  test('names are unique', () {
    expect(surahs.map((s) => s.name).toSet(), hasLength(114));
  });

  group('validateAyahRange', () {
    test('accepts valid ranges, including a single ayah and the full surah', () {
      expect(validateAyahRange(1, 1, 7), isNull);
      expect(validateAyahRange(2, 5, 5), isNull);
      expect(validateAyahRange(114, 1, 6), isNull);
    });
    test('rejects out-of-bounds, reversed and unknown', () {
      expect(validateAyahRange(1, 1, 8), isNotNull);
      expect(validateAyahRange(1, 0, 3), isNotNull);
      expect(validateAyahRange(1, 5, 3), isNotNull);
      expect(validateAyahRange(115, 1, 1), isNotNull);
      expect(validateAyahRange(0, 1, 1), isNotNull);
    });
  });
}
