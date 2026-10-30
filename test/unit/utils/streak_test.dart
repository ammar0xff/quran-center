import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/streak.dart';
import 'package:quran_center/data/models/enums.dart';

({DateTime date, AttendanceStatus status}) _r(int day, AttendanceStatus s) =>
    (date: DateTime(2026, 11, day), status: s);

void main() {
  const p = AttendanceStatus.present, l = AttendanceStatus.late;
  const a = AttendanceStatus.absent, e = AttendanceStatus.excused;

  test('no records means no streak', () => expect(attendanceStreak([]), 0));
  test('counts present and late back from the latest session', () {
    expect(attendanceStreak([_r(1, p), _r(2, l), _r(3, p)]), 3);
  });
  test('the first absence going backwards ends it, whatever order they come in', () {
    expect(attendanceStreak([_r(5, p), _r(1, a), _r(4, p), _r(2, p), _r(3, a)]), 2);
  });
  test('an absence in the latest session means zero', () {
    expect(attendanceStreak([_r(1, p), _r(2, p), _r(3, a)]), 0);
  });
  test('excused sessions neither count nor break the streak', () {
    expect(attendanceStreak([_r(1, p), _r(2, e), _r(3, e), _r(4, p)]), 2);
    expect(attendanceStreak([_r(1, a), _r(2, e)]), 0);
  });
}
