import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/audit_log.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';

/// Everything the director's student profile shows, loaded together.
class StudentProfileData {
  const StudentProfileData({
    required this.student,
    required this.enrollments,
    required this.circleNames,
    required this.teacherNames,
    required this.attendance,
    required this.sessionDates,
    required this.audit,
    required this.userNames,
    this.adminNote,
  });

  final Student student;

  /// Active and closed enrolments, newest first.
  final List<Enrollment> enrollments;
  final Map<String, String> circleNames;
  final Map<String, String> teacherNames;

  /// Newest session first.
  final List<Attendance> attendance;
  final Map<String, DateTime> sessionDates;
  final List<AuditLog> audit;

  /// Display names of the center's users, to show who made each change.
  final Map<String, String> userNames;

  /// Staff-only note (separate document; never visible to the student).
  final String? adminNote;

  Enrollment? get currentEnrollment {
    for (final e in enrollments) {
      if (e.status == EnrollmentStatus.active) return e;
    }
    return null;
  }

  AttendanceSummary get attendanceSummary => AttendanceSummary.from(attendance);
}

/// Loads a student's profile for the signed-in director.
///
/// Returns null when the student does not exist OR belongs to another center
/// (the two are indistinguishable to the user). Every query is scoped to the
/// director's center, as the Security Rules require.
final studentProfileProvider = FutureProvider.autoDispose
    .family<StudentProfileData?, String>((ref, studentId) async {
  final centerId = ref.watch(centerIdProvider);
  final student = await ref.read(studentRepositoryProvider).getStudent(studentId);
  if (student == null || student.centerId != centerId) return null;

  final (enrollments, circles, teachers, records, schedules, audit, users, note) = await (
    ref.read(enrollmentRepositoryProvider).getHistoryForStudent(studentId, centerId: centerId),
    ref.read(circleRepositoryProvider).getCirclesByCenter(centerId),
    ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId),
    ref.read(attendanceRepositoryProvider).getByStudent(studentId, centerId: centerId),
    ref.read(scheduleRepositoryProvider).getSchedulesByCenter(centerId),
    ref.read(auditRepositoryProvider).getForEntity('student', studentId, centerId: centerId),
    ref.read(userRepositoryProvider).getUsersByCenter(centerId),
    ref.read(studentRepositoryProvider).getAdminNote(studentId, centerId: centerId),
  ).wait;

  final sessionDates = {for (final s in schedules) s.scheduleId: s.date};
  final sorted = [...records]..sort((a, b) {
      final da = sessionDates[a.sessionId] ?? a.createdAt;
      final db = sessionDates[b.sessionId] ?? b.createdAt;
      return db.compareTo(da);
    });

  return StudentProfileData(
    student: student,
    enrollments: enrollments,
    circleNames: {for (final c in circles) c.circleId: c.name},
    teacherNames: {for (final t in teachers) t.teacherId: t.fullName},
    attendance: sorted,
    sessionDates: sessionDates,
    audit: audit,
    userNames: {for (final u in users) u.uid: u.fullName},
    adminNote: note,
  );
});

/// Arabic text for an audit action; unknown actions are shown as recorded.
String auditActionLabel(String action) {
  switch (action) {
    case 'update_student':
      return 'تعديل بيانات الطالب';
    case 'archive_student':
      return 'أرشفة الطالب';
    case 'reinstate_student':
      return 'إعادة تفعيل الطالب';
    case 'assign_student':
      return 'تعيين لحلقة';
    case 'transfer_student':
      return 'نقل إلى حلقة أخرى';
    case 'enable_student_access':
      return 'تفعيل الدخول';
    case 'suspend_student_access':
      return 'تعليق الدخول';
    case 'reactivate_student_access':
      return 'إعادة تفعيل الدخول';
    default:
      return action;
  }
}
