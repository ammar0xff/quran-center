import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/providers/repositories.dart';

class TeacherHomeData {
  const TeacherHomeData({
    required this.studentCount,
    required this.circles,
    required this.todaySessions,
    required this.circleNames,
    required this.upcoming,
    this.awaitingVerification = 0,
    this.overdueTasks = 0,
  });

  final int studentCount;
  final List<Circle> circles;

  /// Today's sessions in time order (cancelled ones included, marked as such).
  final List<Schedule> todaySessions;
  final Map<String, String> circleNames;

  /// The next few future scheduled sessions.
  final List<Schedule> upcoming;

  /// Tasks the student reported practicing that the teacher has not verified.
  final int awaitingVerification;

  /// Open tasks past their due date.
  final int overdueTasks;

  bool get hasAssignments => circles.isNotEmpty || studentCount > 0;
}

/// Loads the signed-in teacher's own workspace summary. Everything is scoped
/// to their center and to themselves.
final teacherHomeProvider =
    FutureProvider.autoDispose<TeacherHomeData>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final teacherId = ref.watch(actorProvider).id;
  final ws = ref.read(teacherWorkspaceProvider);
  final now = DateTime.now();

  final (sessions, circles, students, tasks) = await (
    ws.sessions(centerId, teacherId),
    ws.circles(centerId, teacherId),
    ws.students(centerId, teacherId),
    ref.read(taskServiceProvider).tasksForTeacher(centerId, teacherId),
  ).wait;

  final activeStudents = students
      .where((s) => s.enrollmentStatus == EnrollmentStatus.active)
      .length;
  final today = sessions.where((s) => s.date.isSameDate(now)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final upcoming = sessions
      .where((s) =>
          s.status == SessionStatus.scheduled &&
          !s.date.isBefore(startOfTomorrow))
      .toList()
    ..sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.startTime.compareTo(b.startTime);
    });

  return TeacherHomeData(
    studentCount: activeStudents,
    circles: circles.where((c) => c.status == CircleStatus.active).toList(),
    todaySessions: today,
    circleNames: {for (final c in circles) c.circleId: c.name},
    upcoming: upcoming.take(3).toList(),
    awaitingVerification: tasks
        .where((t) =>
            t.status == TaskStatus.practiceReported ||
            t.status == TaskStatus.submittedForReview)
        .length,
    overdueTasks: tasks.where((t) => t.isOverdue).length,
  );
});

String sessionStatusLabel(SessionStatus s) {
  switch (s) {
    case SessionStatus.scheduled:
      return 'لم تبدأ';
    case SessionStatus.inProgress:
      return 'جارية';
    case SessionStatus.completed:
      return 'منتهية';
    case SessionStatus.cancelled:
      return 'ملغاة';
  }
}
