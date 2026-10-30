import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/teacher.dart';

/// Everything the reports are computed from. Nothing else is consulted.
class ReportData {
  const ReportData({
    required this.students,
    required this.circles,
    required this.teachers,
    required this.schedules,
    required this.attendance,
    required this.assessments,
    required this.tasks,
  });

  final List<Student> students;
  final List<Circle> circles;
  final List<Teacher> teachers;
  final List<Schedule> schedules;
  final List<Attendance> attendance;
  final List<MemorizationRecord> assessments;
  final List<LearningTask> tasks;
}

/// Inclusive start, exclusive end. Null bounds mean "no limit".
class ReportPeriod {
  const ReportPeriod({this.from, this.to});
  final DateTime? from;
  final DateTime? to;

  bool contains(DateTime d) =>
      (from == null || !d.isBefore(from!)) && (to == null || d.isBefore(to!));
}

/// The day an attendance record belongs to: its session's date, else the day
/// it was recorded.
DateTime attendanceDay(Attendance a, Map<String, Schedule> sessions) =>
    sessions[a.sessionId]?.date ?? a.createdAt;

class AttendanceRow {
  const AttendanceRow(this.studentId, this.name, this.circleName, this.summary);
  final String studentId;
  final String name;
  final String circleName;
  final AttendanceSummary summary;
}

/// Attendance per active student. The rate is (present + late) / (present +
/// late + absent); excused and missing records are excluded, and a student
/// with no records has NO rate (never 0%).
List<AttendanceRow> attendanceByStudent(
  ReportData d,
  ReportPeriod period, {
  String? circleId,
}) {
  final sessions = {for (final s in d.schedules) s.scheduleId: s};
  final circleName = {for (final c in d.circles) c.circleId: c.name};
  final byStudent = <String, List<Attendance>>{};
  for (final a in d.attendance) {
    if (period.contains(attendanceDay(a, sessions))) {
      (byStudent[a.studentId] ??= []).add(a);
    }
  }
  final rows = [
    for (final s in d.students)
      if (s.enrollmentStatus == EnrollmentStatus.active &&
          (circleId == null || s.currentCircleId == circleId))
        AttendanceRow(
          s.studentId,
          s.displayName,
          circleName[s.currentCircleId] ?? '',
          AttendanceSummary.from(byStudent[s.studentId] ?? const []),
        ),
  ]..sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

class TeacherActivityRow {
  const TeacherActivityRow({
    required this.teacherId,
    required this.name,
    required this.sessionsCompleted,
    required this.sessionsScheduled,
    required this.attendanceRecorded,
    required this.assessments,
    required this.tasksAwaitingVerification,
  });
  final String teacherId;
  final String name;
  final int sessionsCompleted;
  final int sessionsScheduled;
  final int attendanceRecorded;
  final int assessments;
  final int tasksAwaitingVerification;
}

/// Counts of work done, per teacher. These measure ACTIVITY, not teaching
/// quality, and the screen says so.
List<TeacherActivityRow> teacherActivity(ReportData d, ReportPeriod period) {
  final sessions = {for (final s in d.schedules) s.scheduleId: s};
  return [
    for (final t in d.teachers)
      TeacherActivityRow(
        teacherId: t.teacherId,
        name: t.fullName,
        sessionsCompleted: d.schedules
            .where((s) =>
                s.teacherId == t.teacherId &&
                s.status == SessionStatus.completed &&
                period.contains(s.date))
            .length,
        sessionsScheduled: d.schedules
            .where((s) =>
                s.teacherId == t.teacherId &&
                s.status != SessionStatus.cancelled &&
                period.contains(s.date))
            .length,
        attendanceRecorded: d.attendance
            .where((a) =>
                a.recordedBy == t.teacherId &&
                period.contains(attendanceDay(a, sessions)))
            .length,
        assessments: d.assessments
            .where((m) =>
                m.teacherId == t.teacherId && period.contains(m.assessedAt))
            .length,
        tasksAwaitingVerification: d.tasks
            .where((k) =>
                k.teacherId == t.teacherId &&
                (k.status == TaskStatus.practiceReported ||
                    k.status == TaskStatus.submittedForReview))
            .length,
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

class CircleRow {
  const CircleRow({
    required this.circleId,
    required this.name,
    required this.teacherName,
    required this.students,
    required this.capacity,
    required this.sessionsCompleted,
    required this.sessionsCancelled,
    required this.summary,
  });
  final String circleId;
  final String name;
  final String teacherName;
  final int students;
  final int capacity;
  final int sessionsCompleted;
  final int sessionsCancelled;
  final AttendanceSummary summary;
}

List<CircleRow> circleOverview(ReportData d, ReportPeriod period) {
  final sessions = {for (final s in d.schedules) s.scheduleId: s};
  final teacherName = {for (final t in d.teachers) t.teacherId: t.fullName};
  return [
    for (final c in d.circles)
      if (c.status == CircleStatus.active)
        CircleRow(
          circleId: c.circleId,
          name: c.name,
          teacherName: teacherName[c.assignedTeacherId] ?? '',
          students: d.students
              .where((s) =>
                  s.enrollmentStatus == EnrollmentStatus.active &&
                  s.currentCircleId == c.circleId)
              .length,
          capacity: c.maxCapacity,
          sessionsCompleted: d.schedules
              .where((s) =>
                  s.circleId == c.circleId &&
                  s.status == SessionStatus.completed &&
                  period.contains(s.date))
              .length,
          sessionsCancelled: d.schedules
              .where((s) =>
                  s.circleId == c.circleId &&
                  s.status == SessionStatus.cancelled &&
                  period.contains(s.date))
              .length,
          summary: AttendanceSummary.from(d.attendance.where((a) {
            final s = sessions[a.sessionId];
            return s != null &&
                s.circleId == c.circleId &&
                period.contains(s.date);
          })),
        ),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// "85.7%" or "—" when there is nothing to base a rate on.
String rateText(AttendanceSummary s) =>
    s.rate == null ? '—' : '${(s.rate! * 100).toStringAsFixed(1)}%';
