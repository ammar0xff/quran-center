import 'package:quran_center/data/models/enums.dart';

/// How many sessions in a row the student attended, counting back from the
/// most recent one.
///
/// * present and late count;
/// * excused sessions are skipped: they neither add to the streak nor break it;
/// * the first absence ends it;
/// * a session with no record is not counted either way (never an absence).
int attendanceStreak(Iterable<({DateTime date, AttendanceStatus status})> records) {
  final sorted = records.toList()..sort((a, b) => b.date.compareTo(a.date));
  var n = 0;
  for (final r in sorted) {
    switch (r.status) {
      case AttendanceStatus.present:
      case AttendanceStatus.late:
        n++;
      case AttendanceStatus.excused:
        continue;
      case AttendanceStatus.absent:
        return n;
    }
  }
  return n;
}
