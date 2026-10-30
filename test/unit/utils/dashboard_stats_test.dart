import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/dashboard_stats.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

final _now = DateTime(2026, 11, 4, 10);
final _t0 = DateTime(2026, 1, 1);

Student _student(String id, EnrollmentStatus s) => Student(
      studentId: id,
      centerId: 'c',
      fullName: id,
      enrollmentStatus: s,
      accountMode: AccountMode.none,
      educationalLevel: 'x',
      createdAt: _t0,
      updatedAt: _t0,
    );

Teacher _teacher(String id, AccountStatus s) => Teacher(
      teacherId: id,
      centerId: 'c',
      fullName: id,
      status: s,
      assignedCircleIds: const [],
      createdAt: _t0,
      updatedAt: _t0,
    );

Circle _circle(String id, CircleStatus s) => Circle(
      circleId: id,
      centerId: 'c',
      name: id,
      educationalLevel: 'x',
      maxCapacity: 10,
      locationOrMode: 'onsite',
      weeklySchedule: const [],
      sessionDurationMinutes: 60,
      status: s,
      createdAt: _t0,
      updatedAt: _t0,
    );

Schedule _sched(String id, DateTime date, SessionStatus s) => Schedule(
      scheduleId: id,
      centerId: 'c',
      circleId: 'c1',
      teacherId: 't1',
      date: date,
      startTime: '08:00',
      endTime: '09:00',
      locationOrMode: 'onsite',
      status: s,
      createdAt: _t0,
      updatedAt: _t0,
    );

Attendance _att(String id, AttendanceStatus s, DateTime created) => Attendance(
      attendanceId: id,
      centerId: 'c',
      sessionId: 'sess',
      studentId: id,
      status: s,
      recordedBy: 't',
      createdAt: created,
      updatedAt: created,
    );

void main() {
  test('an empty center yields all zeros and no attendance rate', () {
    final s = computeDashboardStats(
        students: [], teachers: [], circles: [], schedules: [], attendance: [], now: _now);
    expect(s.activeStudents, 0);
    expect(s.activeTeachers, 0);
    expect(s.activeCircles, 0);
    expect(s.todaySessions, 0);
    expect(s.weekAttendance.rate, isNull);
  });

  test('counts only active students, teachers and circles', () {
    final s = computeDashboardStats(
      students: [
        _student('a', EnrollmentStatus.active),
        _student('b', EnrollmentStatus.active),
        _student('c', EnrollmentStatus.archived),
        _student('d', EnrollmentStatus.withdrawn),
      ],
      teachers: [
        _teacher('a', AccountStatus.active),
        _teacher('b', AccountStatus.suspended),
      ],
      circles: [
        _circle('a', CircleStatus.active),
        _circle('b', CircleStatus.archived),
      ],
      schedules: [],
      attendance: [],
      now: _now,
    );
    expect(s.activeStudents, 2);
    expect(s.activeTeachers, 1);
    expect(s.activeCircles, 1);
  });

  test('today\'s sessions are split by status; other days are ignored', () {
    final today = DateTime(2026, 11, 4);
    final s = computeDashboardStats(
      students: [],
      teachers: [],
      circles: [],
      schedules: [
        _sched('1', today, SessionStatus.scheduled),
        _sched('2', today, SessionStatus.scheduled),
        _sched('3', today, SessionStatus.inProgress),
        _sched('4', today, SessionStatus.completed),
        _sched('5', today, SessionStatus.cancelled),
        _sched('6', DateTime(2026, 11, 5), SessionStatus.scheduled),
        _sched('7', DateTime(2026, 11, 3), SessionStatus.completed),
      ],
      attendance: [],
      now: _now,
    );
    expect(s.todayScheduled, 2);
    expect(s.todayInProgress, 1);
    expect(s.todayCompleted, 1);
    expect(s.todayCancelled, 1);
    // A cancelled session is not a session that will take place.
    expect(s.todaySessions, 4);
  });

  test('attendance covers the last 7 days only and uses the documented rate', () {
    final s = computeDashboardStats(
      students: [],
      teachers: [],
      circles: [],
      schedules: [],
      attendance: [
        _att('a', AttendanceStatus.present, _now.subtract(const Duration(days: 1))),
        _att('b', AttendanceStatus.late, _now.subtract(const Duration(days: 2))),
        _att('c', AttendanceStatus.absent, _now.subtract(const Duration(days: 3))),
        _att('d', AttendanceStatus.excused, _now.subtract(const Duration(days: 3))),
        // Older than a week: must not be counted.
        _att('e', AttendanceStatus.absent, _now.subtract(const Duration(days: 8))),
        _att('f', AttendanceStatus.absent, _now.subtract(const Duration(days: 30))),
      ],
      now: _now,
    );
    expect(s.weekAttendance.present, 1);
    expect(s.weekAttendance.late, 1);
    expect(s.weekAttendance.absent, 1);
    expect(s.weekAttendance.excused, 1);
    // (present + late) / (present + late + absent) = 2/3; excused ignored.
    expect(s.weekAttendance.rate, closeTo(2 / 3, 1e-9));
  });
}
