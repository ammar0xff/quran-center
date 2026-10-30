import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

/// Director dashboard numbers, derived only from the records passed in.
///
/// Definitions (also stated on screen):
/// * active students  = enrollmentStatus is `active`
/// * active teachers  = account status is `active`
/// * active circles   = status is `active`
/// * sessions today   = schedules dated today, by status
/// * attendance       = records created in the last 7 days, summarised with
///   [AttendanceSummary] (late counts as attended; excused and missing are
///   excluded from the rate; a missing record is not an absence).
class DashboardStats {
  const DashboardStats({
    required this.activeStudents,
    required this.activeTeachers,
    required this.activeCircles,
    required this.todayScheduled,
    required this.todayInProgress,
    required this.todayCompleted,
    required this.todayCancelled,
    required this.weekAttendance,
  });

  final int activeStudents;
  final int activeTeachers;
  final int activeCircles;
  final int todayScheduled;
  final int todayInProgress;
  final int todayCompleted;
  final int todayCancelled;
  final AttendanceSummary weekAttendance;

  /// Sessions that are (or were) actually going to happen today.
  int get todaySessions => todayScheduled + todayInProgress + todayCompleted;
}

DashboardStats computeDashboardStats({
  required Iterable<Student> students,
  required Iterable<Teacher> teachers,
  required Iterable<Circle> circles,
  required Iterable<Schedule> schedules,
  required Iterable<Attendance> attendance,
  required DateTime now,
}) {
  var scheduled = 0, inProgress = 0, completed = 0, cancelled = 0;
  for (final s in schedules) {
    if (!s.date.isSameDate(now)) continue;
    switch (s.status) {
      case SessionStatus.scheduled:
        scheduled++;
      case SessionStatus.inProgress:
        inProgress++;
      case SessionStatus.completed:
        completed++;
      case SessionStatus.cancelled:
        cancelled++;
    }
  }

  final since = now.subtract(const Duration(days: 7));
  final recent = attendance.where((a) => a.createdAt.isAfter(since));

  return DashboardStats(
    activeStudents:
        students.where((s) => s.enrollmentStatus == EnrollmentStatus.active).length,
    activeTeachers:
        teachers.where((t) => t.status == AccountStatus.active).length,
    activeCircles: circles.where((c) => c.status == CircleStatus.active).length,
    todayScheduled: scheduled,
    todayInProgress: inProgress,
    todayCompleted: completed,
    todayCancelled: cancelled,
    weekAttendance: AttendanceSummary.from(recent),
  );
}
