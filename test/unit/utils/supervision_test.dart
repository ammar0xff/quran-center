import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/core/utils/supervision.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

final _now = DateTime(2026, 11, 20, 10);
final _t = DateTime(2026);

Student _stu(String id, {EnrollmentStatus st = EnrollmentStatus.active}) => Student(
    studentId: id, centerId: 'c', fullName: id, enrollmentStatus: st, accountMode: AccountMode.none,
    currentCircleId: 'cA', educationalLevel: 'x', createdAt: _t, updatedAt: _t);

Schedule _sess(String id, DateTime date, {SessionStatus st = SessionStatus.completed}) => Schedule(
    scheduleId: id, centerId: 'c', circleId: 'cA', teacherId: 't1', date: date, startTime: '08:00',
    endTime: '09:00', locationOrMode: 'onsite', status: st, createdAt: _t, updatedAt: _t);

Attendance _att(String sess, String student, AttendanceStatus st) => Attendance(
    attendanceId: '${sess}_$student', centerId: 'c', sessionId: sess, studentId: student, status: st,
    recordedBy: 't1', createdAt: _t, updatedAt: _t);

LearningTask _task(String id, TaskStatus st, DateTime due,
        {String student = 's1', SelfReportedPractice? claim}) =>
    LearningTask(taskId: id, centerId: 'c', planId: 'p', studentId: student, teacherId: 't1',
        taskType: TaskType.recentRevision, surah: 1, startAyah: 1, endAyah: 2, assignedDate: _t,
        dueDate: due, teacherInstructions: '', status: st, selfReportedPractice: claim,
        createdAt: _t, updatedAt: _t);

ReportData _data({
  List<Student>? students,
  List<Schedule> schedules = const [],
  List<Attendance> attendance = const [],
  List<LearningTask> tasks = const [],
}) =>
    ReportData(
      students: students ?? [_stu('s1')],
      circles: [Circle(circleId: 'cA', centerId: 'c', name: 'حلقة', educationalLevel: 'x', maxCapacity: 5,
          locationOrMode: 'onsite', weeklySchedule: const [], sessionDurationMinutes: 60,
          status: CircleStatus.active, createdAt: _t, updatedAt: _t)],
      teachers: [Teacher(teacherId: 't1', centerId: 'c', fullName: 'معلمة', status: AccountStatus.active,
          assignedCircleIds: const [], createdAt: _t, updatedAt: _t)],
      schedules: schedules,
      attendance: attendance,
      assessments: const [],
      tasks: tasks,
    );

void main() {
  test('nothing to report for a quiet center', () {
    expect(followUps(_data(), _now), isEmpty);
  });

  group('overdue tasks', () {
    test('open and past due is listed with how late; completed, cancelled and future are not', () {
      final items = followUps(
          _data(tasks: [
            _task('late', TaskStatus.inProgress, DateTime(2026, 11, 15)),
            _task('done', TaskStatus.completed, DateTime(2026, 11, 1)),
            _task('gone', TaskStatus.cancelled, DateTime(2026, 11, 1)),
            _task('future', TaskStatus.upcoming, DateTime(2026, 12, 1)),
          ]),
          _now);
      expect(items, hasLength(1));
      expect(items.single.kind, FollowUpKind.overdueTask);
      expect(items.single.reason, contains('5 يومًا'));
      expect(items.single.studentName, 's1');
      expect(items.single.teacherName, 'معلمة');
    });

    test('an archived student\'s tasks are not chased', () {
      expect(
          followUps(
              _data(students: [_stu('s1', st: EnrollmentStatus.archived)], tasks: [
                _task('late', TaskStatus.inProgress, DateTime(2026, 11, 1)),
              ]),
              _now),
          isEmpty);
    });
  });

  group('awaiting verification', () {
    test('only after more than a week', () {
      SelfReportedPractice claim(int daysAgo) =>
          SelfReportedPractice(reportedAt: _now.subtract(Duration(days: daysAgo)));
      final items = followUps(
          _data(tasks: [
            _task('fresh', TaskStatus.practiceReported, DateTime(2026, 12, 30), claim: claim(3)),
            _task('stale', TaskStatus.submittedForReview, DateTime(2026, 12, 30), claim: claim(9)),
          ]),
          _now);
      expect(items.map((i) => i.kind), [FollowUpKind.awaitingVerification]);
      expect(items.single.reason, contains('9 يومًا'));
    });
  });

  group('repeated absence', () {
    List<Schedule> days(int n) =>
        [for (var i = 0; i < n; i++) _sess('x$i', DateTime(2026, 11, 1 + i))];

    test('3 absences in the last 5 counted sessions', () {
      final att = [
        _att('x0', 's1', AttendanceStatus.absent),
        _att('x1', 's1', AttendanceStatus.present),
        _att('x2', 's1', AttendanceStatus.absent),
        _att('x3', 's1', AttendanceStatus.late),
        _att('x4', 's1', AttendanceStatus.absent),
      ];
      final items = followUps(_data(schedules: days(5), attendance: att), _now);
      final r = items.where((i) => i.kind == FollowUpKind.repeatedAbsence).single;
      expect(r.reason, 'غاب 3 مرات من آخر 5 جلسات مسجّلة');
      expect(r.date, DateTime(2026, 11, 5)); // the latest absence
    });

    test('excused sessions are not absences and do not count in the window', () {
      final att = [
        _att('x0', 's1', AttendanceStatus.absent),
        _att('x1', 's1', AttendanceStatus.excused),
        _att('x2', 's1', AttendanceStatus.excused),
        _att('x3', 's1', AttendanceStatus.excused),
        _att('x4', 's1', AttendanceStatus.absent),
      ];
      expect(followUps(_data(schedules: days(5), attendance: att), _now)
          .where((i) => i.kind == FollowUpKind.repeatedAbsence), isEmpty);
    });

    test('old absences outside the last five do not count; missing records are not absences', () {
      final att = [
        _att('x0', 's1', AttendanceStatus.absent),
        _att('x1', 's1', AttendanceStatus.absent),
        _att('x2', 's1', AttendanceStatus.absent),
        // five later sessions attended
        for (var i = 3; i < 8; i++) _att('x$i', 's1', AttendanceStatus.present),
      ];
      expect(followUps(_data(schedules: days(8), attendance: att), _now)
          .where((i) => i.kind == FollowUpKind.repeatedAbsence), isEmpty);
    });
  });

  test('a completed session with no attendance at all is flagged; started or empty-but-scheduled are not', () {
    final items = followUps(
        _data(schedules: [
          _sess('empty', DateTime(2026, 11, 3)),
          _sess('recorded', DateTime(2026, 11, 4)),
          _sess('later', DateTime(2026, 11, 25), st: SessionStatus.scheduled),
        ], attendance: [
          _att('recorded', 's1', AttendanceStatus.present),
        ]),
        _now);
    expect(items, hasLength(1));
    expect(items.single.kind, FollowUpKind.sessionWithoutAttendance);
    expect(items.single.date, DateTime(2026, 11, 3));
    expect(items.single.studentName, isNull);
  });

  test('newest first; every kind has its own label', () {
    final items = followUps(
        _data(tasks: [
          _task('a', TaskStatus.inProgress, DateTime(2026, 11, 1)),
          _task('b', TaskStatus.inProgress, DateTime(2026, 11, 10)),
        ]),
        _now);
    expect(items.first.date, DateTime(2026, 11, 10));
    expect(FollowUpKind.values.map(followUpKindLabel).toSet(), hasLength(FollowUpKind.values.length));
  });
}
