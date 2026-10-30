import 'package:quran_center/data/models/enums.dart';

/// Who is changing a task's status.
enum TaskActor { teacher, student }

/// The task status machine.
///
/// * `overdue` is NEVER stored. It is derived from the due date
///   ([LearningTask.isOverdue]); nobody can move a task to it.
/// * `completed` is only ever reached by a teacher's verification. A student's
///   report ("I practiced") moves a task to `practiceReported` /
///   `submittedForReview`, which is a claim, not a result.
/// * `completed` and `cancelled` are final.
///
/// Student:  upcoming -> inProgress -> practiceReported -> submittedForReview,
///           upcoming -> practiceReported, needsReview -> inProgress |
///           practiceReported
/// Teacher:  any open status -> completed | needsReview (a verification), or
///           -> cancelled (with a reason)
bool canTransition(TaskStatus from, TaskStatus to, TaskActor actor) {
  const open = {
    TaskStatus.upcoming,
    TaskStatus.inProgress,
    TaskStatus.practiceReported,
    TaskStatus.submittedForReview,
    TaskStatus.needsReview,
  };
  if (!open.contains(from)) return false; // final or derived states
  switch (actor) {
    case TaskActor.teacher:
      return to == TaskStatus.completed ||
          to == TaskStatus.needsReview && from != TaskStatus.needsReview ||
          to == TaskStatus.cancelled;
    case TaskActor.student:
      switch (from) {
        case TaskStatus.upcoming:
          return to == TaskStatus.inProgress || to == TaskStatus.practiceReported;
        case TaskStatus.inProgress:
          return to == TaskStatus.practiceReported;
        case TaskStatus.practiceReported:
          return to == TaskStatus.submittedForReview;
        case TaskStatus.needsReview:
          return to == TaskStatus.inProgress || to == TaskStatus.practiceReported;
        default:
          return false;
      }
  }
}

/// Task result recorded by a teacher's verification.
const verificationPassed = 'passed';
const verificationNeedsImprovement = 'needs_improvement';

TaskStatus statusForVerification(String result) =>
    result == verificationPassed ? TaskStatus.completed : TaskStatus.needsReview;

String taskStatusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.upcoming:
      return 'قادمة';
    case TaskStatus.inProgress:
      return 'قيد العمل';
    case TaskStatus.practiceReported:
      return 'أبلغ عن التدريب';
    case TaskStatus.submittedForReview:
      return 'بانتظار المراجعة';
    case TaskStatus.completed:
      return 'مكتملة';
    case TaskStatus.needsReview:
      return 'تحتاج إعادة';
    case TaskStatus.overdue:
      return 'متأخرة';
    case TaskStatus.cancelled:
      return 'ملغاة';
  }
}

String taskTypeLabel(TaskType t) {
  switch (t) {
    case TaskType.newMemorization:
      return 'حفظ جديد';
    case TaskType.recentRevision:
      return 'مراجعة قريبة';
    case TaskType.longTermRevision:
      return 'مراجعة بعيدة';
    case TaskType.generalRecitation:
      return 'تلاوة عامة';
  }
}
