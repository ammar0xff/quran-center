import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

/// Why a student cannot be assigned to a circle.
enum AssignmentError { studentNotActive, circleNotActive, circleFull, alreadyInCircle }

/// What assigning a student to a circle will do.
class AssignmentPlan {
  const AssignmentPlan({required this.toTransfer, required this.teacherId});

  /// The student's current active enrolments in OTHER circles. They are closed
  /// as `transferred` (never deleted), so history is kept.
  final List<Enrollment> toTransfer;

  /// The circle's teacher; becomes the student's assigned teacher. Null when
  /// the circle has no teacher yet.
  final String? teacherId;

  /// The student's `assignedTeacherIds` after the change. Security Rules use
  /// this field to decide which teacher may read the student.
  List<String> get studentTeacherIds => teacherId == null ? const [] : [teacherId!];
}

class AssignmentResult {
  const AssignmentResult.ok(AssignmentPlan this.plan) : error = null;
  const AssignmentResult.failed(AssignmentError this.error) : plan = null;

  final AssignmentPlan? plan;
  final AssignmentError? error;
}

/// Decides an assignment. Policy (documented in docs/workflows.md):
///
/// * A student has at most ONE active enrolment at a time. Assigning to a new
///   circle is a transfer: the previous enrolment is closed as `transferred`.
/// * Only active students can be assigned, and only to active circles.
/// * A circle cannot exceed its capacity. [circleActiveCount] counts the
///   circle's active enrolments; a student already in the circle is rejected
///   as a duplicate before capacity is considered.
AssignmentResult planAssignment({
  required Student student,
  required Circle circle,
  required List<Enrollment> studentActiveEnrollments,
  required int circleActiveCount,
}) {
  if (student.enrollmentStatus != EnrollmentStatus.active) {
    return const AssignmentResult.failed(AssignmentError.studentNotActive);
  }
  if (circle.status != CircleStatus.active) {
    return const AssignmentResult.failed(AssignmentError.circleNotActive);
  }
  final active = studentActiveEnrollments.where((e) => e.isActive).toList();
  if (active.any((e) => e.circleId == circle.circleId)) {
    return const AssignmentResult.failed(AssignmentError.alreadyInCircle);
  }
  if (circleActiveCount >= circle.maxCapacity) {
    return const AssignmentResult.failed(AssignmentError.circleFull);
  }
  return AssignmentResult.ok(AssignmentPlan(
    toTransfer: active,
    teacherId: circle.assignedTeacherId,
  ));
}

String assignmentErrorMessage(AssignmentError e) {
  switch (e) {
    case AssignmentError.studentNotActive:
      return 'لا يمكن تعيين طالب غير منتظم.';
    case AssignmentError.circleNotActive:
      return 'هذه الحلقة مؤرشفة ولا تقبل طلابًا.';
    case AssignmentError.circleFull:
      return 'الحلقة ممتلئة. ارفع السعة أو اختر حلقة أخرى.';
    case AssignmentError.alreadyInCircle:
      return 'الطالب مسجّل في هذه الحلقة بالفعل.';
  }
}
