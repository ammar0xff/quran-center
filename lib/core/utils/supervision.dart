import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/data/models/enums.dart';

enum FollowUpKind {
  overdueTask,
  awaitingVerification,
  repeatedAbsence,
  sessionWithoutAttendance
}

/// One thing the director may want to look into, with the plain facts that put
/// it here. It is a pointer to records, not a judgement of anyone.
class FollowUpItem {
  const FollowUpItem({
    required this.kind,
    required this.reason,
    required this.date,
    this.studentId,
    this.studentName,
    this.circleName,
    this.teacherName,
  });

  final FollowUpKind kind;
  final String reason;

  /// The date the facts refer to (due date, report date, latest absence, session).
  final DateTime date;
  final String? studentId;
  final String? studentName;
  final String? circleName;
  final String? teacherName;
}

const repeatedAbsenceWindow = 5;
const repeatedAbsenceThreshold = 3;
const awaitingVerificationDays = 7;

/// Rules (shown on screen too):
/// * overdue task: open (not completed/cancelled) and past its due date;
/// * awaiting verification: the student reported practice and the teacher has
///   not verified it for more than [awaitingVerificationDays] days;
/// * repeated absence: [repeatedAbsenceThreshold] or more absences among the
///   student's last [repeatedAbsenceWindow] counted sessions (excused ones are
///   not counted; a missing record is not an absence);
/// * session without attendance: a completed session with no attendance record.
List<FollowUpItem> followUps(ReportData d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final studentName = {for (final s in d.students) s.studentId: s.displayName};
  final activeStudent = {
    for (final s in d.students)
      if (s.enrollmentStatus == EnrollmentStatus.active) s.studentId: s
  };
  final circleName = {for (final c in d.circles) c.circleId: c.name};
  final teacherName = {for (final t in d.teachers) t.teacherId: t.fullName};
  final sessions = {for (final s in d.schedules) s.scheduleId: s};
  final items = <FollowUpItem>[];

  for (final t in d.tasks) {
    if (!activeStudent.containsKey(t.studentId)) continue;
    final circle = circleName[activeStudent[t.studentId]!.currentCircleId];
    final open =
        t.status != TaskStatus.completed && t.status != TaskStatus.cancelled;
    if (open && t.dueDate.isBefore(today)) {
      final days = today
          .difference(DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day))
          .inDays;
      items.add(FollowUpItem(
        kind: FollowUpKind.overdueTask,
        reason: 'مهمة تجاوزت موعدها بـ $days يومًا',
        date: t.dueDate,
        studentId: t.studentId,
        studentName: studentName[t.studentId],
        circleName: circle,
        teacherName: teacherName[t.teacherId],
      ));
    }
    final claim = t.selfReportedPractice;
    if ((t.status == TaskStatus.practiceReported ||
            t.status == TaskStatus.submittedForReview) &&
        claim != null) {
      final waiting = now.difference(claim.reportedAt).inDays;
      if (waiting > awaitingVerificationDays) {
        items.add(FollowUpItem(
          kind: FollowUpKind.awaitingVerification,
          reason:
              'أبلغ الطالب عن تدريبه منذ $waiting يومًا ولم يتحقق المعلم بعد',
          date: claim.reportedAt,
          studentId: t.studentId,
          studentName: studentName[t.studentId],
          circleName: circle,
          teacherName: teacherName[t.teacherId],
        ));
      }
    }
  }

  final byStudent = <String, List<(DateTime, bool)>>{}; // (day, absent?)
  for (final a in d.attendance) {
    if (a.status == AttendanceStatus.excused) continue;
    (byStudent[a.studentId] ??= [])
        .add((attendanceDay(a, sessions), a.status == AttendanceStatus.absent));
  }
  byStudent.forEach((id, list) {
    final student = activeStudent[id];
    if (student == null) return;
    list.sort((a, b) => b.$1.compareTo(a.$1));
    final recent = list.take(repeatedAbsenceWindow).toList();
    final absences = recent.where((e) => e.$2).toList();
    if (absences.length >= repeatedAbsenceThreshold) {
      items.add(FollowUpItem(
        kind: FollowUpKind.repeatedAbsence,
        reason:
            'غاب ${absences.length} مرات من آخر ${recent.length} جلسات مسجّلة',
        date: absences.first.$1,
        studentId: id,
        studentName: student.displayName,
        circleName: circleName[student.currentCircleId],
      ));
    }
  });

  final recordedSessions = {for (final a in d.attendance) a.sessionId};
  for (final s in d.schedules) {
    if (s.status == SessionStatus.completed &&
        !recordedSessions.contains(s.scheduleId)) {
      items.add(FollowUpItem(
        kind: FollowUpKind.sessionWithoutAttendance,
        reason: 'جلسة منتهية بلا أي سجل حضور',
        date: s.date,
        circleName: circleName[s.circleId],
        teacherName: teacherName[s.teacherId],
      ));
    }
  }

  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
}

String followUpKindLabel(FollowUpKind k) {
  switch (k) {
    case FollowUpKind.overdueTask:
      return 'مهام متأخرة';
    case FollowUpKind.awaitingVerification:
      return 'بانتظار تحقق المعلم';
    case FollowUpKind.repeatedAbsence:
      return 'غياب متكرر';
    case FollowUpKind.sessionWithoutAttendance:
      return 'جلسات بلا حضور';
  }
}
