import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';

class RosterEntry {
  const RosterEntry(this.enrollment, this.student);
  final Enrollment enrollment;

  /// Null only if the student record could not be found.
  final Student? student;
}

class CircleDetailData {
  const CircleDetailData({
    required this.circle,
    required this.teacherName,
    required this.roster,
  });

  final Circle circle;
  final String? teacherName;
  final List<RosterEntry> roster;
}

/// Loads a circle and its current students for the signed-in director.
/// Null when the circle does not exist or belongs to another center.
final circleDetailProvider = FutureProvider.autoDispose
    .family<CircleDetailData?, String>((ref, circleId) async {
  final centerId = ref.watch(centerIdProvider);
  final circle = await ref.read(circleRepositoryProvider).getCircle(circleId);
  if (circle == null || circle.centerId != centerId) return null;

  final (enrollments, students, teachers) = await (
    ref.read(enrollmentRepositoryProvider).getActiveEnrollmentsForCircle(circleId, centerId: centerId),
    ref.read(studentRepositoryProvider).getStudentsByCenter(centerId),
    ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId),
  ).wait;

  final byId = {for (final s in students) s.studentId: s};
  final roster = [for (final e in enrollments) RosterEntry(e, byId[e.studentId])]
    ..sort((a, b) => (a.student?.displayName ?? '').compareTo(b.student?.displayName ?? ''));
  final teacherName = circle.assignedTeacherId == null
      ? null
      : teachers.where((t) => t.teacherId == circle.assignedTeacherId).firstOrNull?.fullName;
  return CircleDetailData(circle: circle, teacherName: teacherName, roster: roster);
});

String circleModeLabel(String mode) {
  switch (mode) {
    case 'onsite':
      return 'حضوري';
    case 'online':
      return 'عن بعد';
    case 'hybrid':
      return 'مختلط';
    default:
      return mode;
  }
}
