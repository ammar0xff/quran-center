import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';

class StudentData {
  const StudentData({
    required this.student,
    required this.circle,
    required this.sessions,
    required this.tasks,
    required this.feedback,
  });

  final Student student;
  final Circle? circle;

  /// All sessions of the student's circle, in date order.
  final List<Schedule> sessions;
  final List<LearningTask> tasks;

  /// Assessments, newest first.
  final List<MemorizationRecord> feedback;

  bool _open(LearningTask t) =>
      t.status != TaskStatus.completed && t.status != TaskStatus.cancelled;

  /// Tasks still to be done, soonest due first.
  List<LearningTask> get openTasks => tasks.where(_open).toList();

  List<LearningTask> get completedTasks =>
      tasks.where((t) => t.status == TaskStatus.completed).toList();

  /// The task to show first: overdue ones, then the soonest due.
  LearningTask? get primaryTask {
    final open = openTasks;
    return open.isEmpty ? null : open.first; // already ordered by due date
  }

  /// The next session that is still going to happen.
  Schedule? nextSession(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (final s in sessions) {
      if (s.status == SessionStatus.cancelled || s.status == SessionStatus.completed) continue;
      if (!s.date.isBefore(today)) return s;
    }
    return null;
  }

  /// Latest assessment that has something written for the student.
  MemorizationRecord? get latestFeedback {
    for (final r in feedback) {
      if (r.studentVisibleFeedback != null ||
          r.strengths != null ||
          r.areasForImprovement != null) {
        return r;
      }
    }
    return null;
  }

  bool isToday(DateTime d, DateTime now) => d.isSameDate(now);
}

/// Loads the signed-in student's own data. The student id comes from their
/// profile, never from anything typed or passed in.
final studentDataProvider = FutureProvider.autoDispose<StudentData>((ref) async {
  final profile = ref.watch(currentSessionProvider).profile;
  final studentId = profile?.studentId;
  if (profile == null || studentId == null) {
    throw StateError('No student profile linked to this account.');
  }
  final ws = ref.read(studentWorkspaceProvider);
  final student = await ws.profile(profile.centerId, studentId);
  if (student == null) throw StateError('Student profile not found.');

  final (circle, sessions, tasks, feedback) = await (
    ws.circle(profile.centerId, student.currentCircleId),
    ws.sessions(profile.centerId, student.currentCircleId),
    ws.tasks(profile.centerId, studentId),
    ws.feedback(profile.centerId, studentId),
  ).wait;
  return StudentData(
    student: student,
    circle: circle,
    sessions: sessions,
    tasks: tasks,
    feedback: feedback,
  );
});
