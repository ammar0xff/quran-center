import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/level_reports.dart';
import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

final _t = DateTime(2026);
int _n = 0;

Student _s(String id, {List<String> teachers = const [], String? circle, EnrollmentStatus st = EnrollmentStatus.active}) =>
    Student(studentId: id, centerId: 'c', fullName: id, enrollmentStatus: st, accountMode: AccountMode.none,
        assignedTeacherIds: teachers, currentCircleId: circle, educationalLevel: 'x', createdAt: _t, updatedAt: _t);

Teacher _tea(String id) => Teacher(teacherId: id, centerId: 'c', fullName: id, status: AccountStatus.active,
    assignedCircleIds: const [], createdAt: _t, updatedAt: _t);

MemorizationRecord _w(String student, String teacher, WirdGrade? g, int daysAgo,
    {AssessmentType type = AssessmentType.newMemorization}) {
  final at = DateTime(2026, 11, 30).subtract(Duration(days: daysAgo));
  return MemorizationRecord(recordId: 'r${_n++}', centerId: 'c', studentId: student, teacherId: teacher,
      assessmentType: type, schemaVersion: 1, surah: 1, startAyah: 1, endAyah: 2, criteriaScores: const {},
      mistakesCount: 0, requiresFollowUp: false, grade: g, assessedAt: at, createdAt: at, updatedAt: at);
}

ReportData _data(List<Student> students, List<MemorizationRecord> w) => ReportData(
    students: students,
    circles: [Circle(circleId: 'cA', centerId: 'c', name: 'الفجر', educationalLevel: 'x', maxCapacity: 5,
        locationOrMode: 'onsite', weeklySchedule: const [], sessionDurationMinutes: 60,
        status: CircleStatus.active, createdAt: _t, updatedAt: _t)],
    teachers: [_tea('t1'), _tea('t2')],
    schedules: const [], attendance: const [], assessments: w, tasks: const []);

void main() {
  test('every active student appears; weakest first; no wirds last with no level', () {
    final rows = studentLevels(_data(
      [_s('strong', teachers: ['t1'], circle: 'cA'), _s('weak', teachers: ['t1']), _s('none'), _s('old', st: EnrollmentStatus.archived)],
      [
        _w('strong', 't1', WirdGrade.excellent, 1),
        _w('weak', 't1', WirdGrade.acceptable, 1),
        _w('old', 't1', WirdGrade.excellent, 1),
      ],
    ));
    expect(rows.map((r) => r.studentId), ['weak', 'strong', 'none']);
    expect(rows.last.level.hasData, isFalse);
    expect(rows.last.level.label, isNull);
    expect(rows.first.circleName, '');
    expect(rows[1].circleName, 'الفجر');
    expect(rows[1].teacherNames, ['t1']);
  });

  test('a visiting teacher\'s marks count toward the student\'s level', () {
    final rows = studentLevels(_data(
      [_s('s', teachers: ['t1'])],
      [_w('s', 't1', WirdGrade.excellent, 3), _w('s', 't2', WirdGrade.veryGood, 1)],
    ));
    expect(rows.single.level.total, 2);
    expect(rows.single.level.average, 4.5);
  });

  test('teacher rows: their students\' level vs the marks they gave, kept apart', () {
    final rows = {
      for (final r in teacherLevels(_data(
        [_s('a', teachers: ['t1']), _s('b', teachers: ['t1']), _s('c', teachers: ['t2'])],
        [
          _w('a', 't1', WirdGrade.excellent, 2),
          _w('b', 't2', WirdGrade.acceptable, 2), // heard by the OTHER teacher as a visitor
          _w('c', 't2', WirdGrade.good, 2),
        ],
      )))
        r.teacherId: r
    };
    final t1 = rows['t1']!;
    expect(t1.students, 2);
    expect(t1.studentsWithLevel, 2);
    expect(t1.studentsAverage, 3.5); // (5 + 2) / 2: b's level includes t2's mark
    expect(t1.wirdsHeard, 1);
    expect(t1.gradeGiven, 5);
    final t2 = rows['t2']!;
    expect(t2.students, 1);
    expect(t2.wirdsHeard, 2); // includes the visiting student b
    expect(t2.gradeGiven, 2.5);
  });

  test('a teacher with no students or wirds has no averages, not zeros', () {
    final t2 = teacherLevels(_data([_s('a', teachers: ['t1'])], [])).firstWhere((r) => r.teacherId == 't2');
    expect(t2.students, 0);
    expect(t2.studentsAverage, isNull);
    expect(t2.gradeGiven, isNull);
    expect(averageText(t2.studentsAverage), '—');
  });

  test('averageText names the level', () {
    expect(averageText(4.2), '4.2 (جيد جدًا)');
    expect(averageText(5), '5.0 (ممتاز)');
  });
}
