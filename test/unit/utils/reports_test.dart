import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/csv.dart';
import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

final _t = DateTime(2026);

Student _stu(String id, {String? circle, EnrollmentStatus st = EnrollmentStatus.active}) => Student(
    studentId: id, centerId: 'c', fullName: id, enrollmentStatus: st, accountMode: AccountMode.none,
    currentCircleId: circle, educationalLevel: 'x', createdAt: _t, updatedAt: _t);

Circle _circ(String id, {String? teacher, int cap = 5}) => Circle(
    circleId: id, centerId: 'c', name: id, educationalLevel: 'x', assignedTeacherId: teacher,
    maxCapacity: cap, locationOrMode: 'onsite', weeklySchedule: const [],
    sessionDurationMinutes: 60, status: CircleStatus.active, createdAt: _t, updatedAt: _t);

Teacher _tea(String id) => Teacher(teacherId: id, centerId: 'c', fullName: id,
    status: AccountStatus.active, assignedCircleIds: const [], createdAt: _t, updatedAt: _t);

Schedule _sess(String id, String circle, String teacher, DateTime date, SessionStatus st) => Schedule(
    scheduleId: id, centerId: 'c', circleId: circle, teacherId: teacher, date: date,
    startTime: '08:00', endTime: '09:00', locationOrMode: 'onsite', status: st,
    createdAt: _t, updatedAt: _t);

Attendance _att(String session, String student, AttendanceStatus st, String by) => Attendance(
    attendanceId: '${session}_$student', centerId: 'c', sessionId: session, studentId: student,
    status: st, recordedBy: by, createdAt: _t, updatedAt: _t);

MemorizationRecord _asm(String id, String teacher, DateTime at) => MemorizationRecord(
    recordId: id, centerId: 'c', studentId: 's1', teacherId: teacher,
    assessmentType: AssessmentType.newMemorization, schemaVersion: 1, surah: 1, startAyah: 1,
    endAyah: 2, criteriaScores: const {}, mistakesCount: 0, requiresFollowUp: false,
    assessedAt: at, createdAt: at, updatedAt: at);

LearningTask _task(String id, String teacher, TaskStatus st) => LearningTask(
    taskId: id, centerId: 'c', planId: 'p', studentId: 's1', teacherId: teacher,
    taskType: TaskType.recentRevision, surah: 1, startAyah: 1, endAyah: 2, assignedDate: _t,
    dueDate: _t, teacherInstructions: '', status: st, createdAt: _t, updatedAt: _t);

void main() {
  final d1 = DateTime(2026, 11, 1);
  final d2 = DateTime(2026, 11, 8);
  final data = ReportData(
    students: [
      _stu('s1', circle: 'cA'), _stu('s2', circle: 'cA'), _stu('s3', circle: 'cB'),
      _stu('gone', circle: 'cA', st: EnrollmentStatus.archived),
    ],
    circles: [_circ('cA', teacher: 't1', cap: 4), _circ('cB', teacher: 't2')],
    teachers: [_tea('t1'), _tea('t2')],
    schedules: [
      _sess('x1', 'cA', 't1', d1, SessionStatus.completed),
      _sess('x2', 'cA', 't1', d2, SessionStatus.completed),
      _sess('x3', 'cA', 't1', d2, SessionStatus.cancelled),
      _sess('y1', 'cB', 't2', d1, SessionStatus.scheduled),
    ],
    attendance: [
      _att('x1', 's1', AttendanceStatus.present, 't1'),
      _att('x1', 's2', AttendanceStatus.absent, 't1'),
      _att('x2', 's1', AttendanceStatus.late, 't1'),
      _att('x2', 's2', AttendanceStatus.excused, 't1'),
    ],
    assessments: [_asm('a1', 't1', d1), _asm('a2', 't1', d2), _asm('a3', 't2', d1)],
    tasks: [
      _task('k1', 't1', TaskStatus.practiceReported),
      _task('k2', 't1', TaskStatus.submittedForReview),
      _task('k3', 't1', TaskStatus.completed),
      _task('k4', 't2', TaskStatus.upcoming),
    ],
  );
  const all = ReportPeriod();

  group('attendance by student', () {
    test('uses the documented rate: excused ignored, no records means no rate', () {
      final rows = attendanceByStudent(data, all);
      final by = {for (final r in rows) r.studentId: r};
      expect(by.containsKey('gone'), isFalse); // archived students are not reported
      expect(by['s1']!.summary.present, 1);
      expect(by['s1']!.summary.late, 1);
      expect(rateText(by['s1']!.summary), '100.0%');
      expect(by['s2']!.summary.absent, 1);
      expect(by['s2']!.summary.excused, 1);
      expect(rateText(by['s2']!.summary), '0.0%'); // 0 attended of 1 counted
      expect(rateText(by['s3']!.summary), '—'); // nothing recorded: not 0%
    });

    test('the period uses the session date', () {
      final week2 = ReportPeriod(from: DateTime(2026, 11, 5), to: DateTime(2026, 11, 12));
      final by = {for (final r in attendanceByStudent(data, week2)) r.studentId: r};
      expect(by['s1']!.summary.present, 0);
      expect(by['s1']!.summary.late, 1);
      expect(by['s2']!.summary.absent, 0);
    });

    test('the circle filter keeps only that circle', () {
      expect(attendanceByStudent(data, all, circleId: 'cB').map((r) => r.studentId), ['s3']);
    });

    test('the end of the period is exclusive', () {
      final upToD1 = ReportPeriod(to: d1);
      expect(attendanceByStudent(data, upToD1).every((r) => r.summary.recorded == 0), isTrue);
    });
  });

  test('teacher activity counts work done, per teacher and period', () {
    final rows = {for (final r in teacherActivity(data, all)) r.teacherId: r};
    expect(rows['t1']!.sessionsCompleted, 2);
    expect(rows['t1']!.sessionsScheduled, 2); // the cancelled one is not "scheduled work"
    expect(rows['t1']!.attendanceRecorded, 4);
    expect(rows['t1']!.assessments, 2);
    expect(rows['t1']!.tasksAwaitingVerification, 2);
    expect(rows['t2']!.sessionsCompleted, 0);
    expect(rows['t2']!.assessments, 1);
    final week2 = ReportPeriod(from: DateTime(2026, 11, 5));
    expect({for (final r in teacherActivity(data, week2)) r.teacherId: r}['t1']!.assessments, 1);
  });

  test('circle overview: seats, sessions and attendance of that circle only', () {
    final rows = {for (final r in circleOverview(data, all)) r.circleId: r};
    expect(rows['cA']!.students, 2);
    expect(rows['cA']!.capacity, 4);
    expect(rows['cA']!.teacherName, 't1');
    expect(rows['cA']!.sessionsCompleted, 2);
    expect(rows['cA']!.sessionsCancelled, 1);
    expect(rowsRate(rows['cA']!), '66.7%'); // (1 present + 1 late) / (+ 1 absent); excused ignored
    expect(rows['cB']!.students, 1);
    expect(rowsRate(rows['cB']!), '—');
  });

  group('csv', () {
    test('quotes commas, quotes and newlines; keeps Arabic as is', () {
      final out = toCsv(['اسم', 'ملاحظة'], [
        ['أحمد', 'a,b'],
        ['x', 'say "hi"'],
        ['y', 'line1\nline2'],
      ]);
      expect(out.split('\r\n').first, 'اسم,ملاحظة');
      expect(out, contains('أحمد,"a,b"'));
      expect(out, contains('x,"say ""hi"""'));
      expect(out, contains('y,"line1\nline2"'));
    });

    test('text a spreadsheet would run as a formula is neutralised; real numbers are not', () {
      final out = toCsv(['h'], [['=SUM(A1)'], ['+cmd'], ['@x'], ['-5'], ['-a'], [42], [null]]);
      final lines = out.split('\r\n');
      expect(lines[1], "'=SUM(A1)");
      expect(lines[2], "'+cmd");
      expect(lines[3], "'@x");
      expect(lines[4], '-5');
      expect(lines[5], "'-a");
      expect(lines[6], '42');
      expect(lines[7], '');
    });
  });
}

String rowsRate(CircleRow r) => rateText(r.summary);
