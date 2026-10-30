import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';

class TeacherStudentList {
  const TeacherStudentList(this.students, this.circleNameOf, this.openTasks);
  final List<Student> students;

  /// studentId -> name of the circle the student attends with this teacher.
  final Map<String, String> circleNameOf;

  /// studentId -> number of open (not completed/cancelled) tasks.
  final Map<String, int> openTasks;
}

/// The signed-in teacher's active students.
final teacherStudentsProvider =
    FutureProvider.autoDispose<TeacherStudentList>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final teacherId = ref.watch(actorProvider).id;
  final ws = ref.read(teacherWorkspaceProvider);
  final (students, circles, enrollments, tasks) = await (
    ws.students(centerId, teacherId),
    ws.circles(centerId, teacherId),
    ws.activeEnrollments(centerId, teacherId),
    ref.read(taskServiceProvider).tasksForTeacher(centerId, teacherId),
  ).wait;

  final circleName = {for (final c in circles) c.circleId: c.name};
  final byStudent = {
    for (final e in enrollments) e.studentId: circleName[e.circleId] ?? ''
  };
  final active = students
      .where((s) => s.enrollmentStatus == EnrollmentStatus.active)
      .toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  final open = <String, int>{};
  for (final t in tasks) {
    if (t.status != TaskStatus.completed && t.status != TaskStatus.cancelled) {
      open[t.studentId] = (open[t.studentId] ?? 0) + 1;
    }
  }
  return TeacherStudentList(active, byStudent, open);
});

class TeacherStudentProfile {
  const TeacherStudentProfile({
    required this.student,
    required this.circle,
    required this.assessments,
    required this.privateNotes,
    required this.tasks,
    required this.attendance,
    required this.sessionDates,
  });

  final Student student;
  final Circle? circle;
  final List<MemorizationRecord> assessments;
  final Map<String, String> privateNotes;
  final List<LearningTask> tasks;
  final List<Attendance> attendance;
  final Map<String, DateTime> sessionDates;

  AttendanceSummary get attendanceSummary => AttendanceSummary.from(attendance);
}

/// One of the teacher's students, with only what this teacher recorded.
/// Null when the student is not (or no longer) assigned to this teacher.
final teacherStudentProfileProvider = FutureProvider.autoDispose
    .family<TeacherStudentProfile?, String>((ref, studentId) async {
  final centerId = ref.watch(centerIdProvider);
  final teacherId = ref.watch(actorProvider).id;
  final ws = ref.read(teacherWorkspaceProvider);

  final students = await ws.students(centerId, teacherId);
  final student = students.where((s) => s.studentId == studentId).firstOrNull;
  if (student == null) return null;

  final (assessments, notes, tasks, attendance, sessions, circles, enrollments) = await (
    ws.assessments(centerId, teacherId, studentId),
    ws.privateNotes(centerId, teacherId, studentId),
    ref.read(taskServiceProvider).tasksForStudent(centerId, teacherId, studentId),
    ws.attendance(centerId, teacherId, studentId),
    ws.sessions(centerId, teacherId),
    ws.circles(centerId, teacherId),
    ws.activeEnrollments(centerId, teacherId),
  ).wait;

  final circleId = enrollments.where((e) => e.studentId == studentId).firstOrNull?.circleId;
  return TeacherStudentProfile(
    student: student,
    circle: circles.where((c) => c.circleId == circleId).firstOrNull,
    assessments: assessments,
    privateNotes: notes,
    tasks: tasks,
    attendance: attendance,
    sessionDates: {for (final s in sessions) s.scheduleId: s.date},
  );
});
