import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/models/enums.dart';

void main() {
  const all = TaskStatus.values;

  test('overdue is derived: nobody can enter or leave it', () {
    for (final actor in TaskActor.values) {
      for (final s in all) {
        expect(canTransition(s, TaskStatus.overdue, actor), isFalse);
        expect(canTransition(TaskStatus.overdue, s, actor), isFalse);
      }
    }
  });

  test('completed and cancelled are final for everyone', () {
    for (final actor in TaskActor.values) {
      for (final from in [TaskStatus.completed, TaskStatus.cancelled]) {
        for (final to in all) {
          expect(canTransition(from, to, actor), isFalse, reason: '$actor $from->$to');
        }
      }
    }
  });

  test('a student can never complete or cancel a task, whatever the state', () {
    for (final from in all) {
      expect(canTransition(from, TaskStatus.completed, TaskActor.student), isFalse);
      expect(canTransition(from, TaskStatus.cancelled, TaskActor.student), isFalse);
      expect(canTransition(from, TaskStatus.needsReview, TaskActor.student), isFalse);
    }
  });

  test('the student\'s path', () {
    bool s(TaskStatus a, TaskStatus b) => canTransition(a, b, TaskActor.student);
    expect(s(TaskStatus.upcoming, TaskStatus.inProgress), isTrue);
    expect(s(TaskStatus.upcoming, TaskStatus.practiceReported), isTrue);
    expect(s(TaskStatus.inProgress, TaskStatus.practiceReported), isTrue);
    expect(s(TaskStatus.practiceReported, TaskStatus.submittedForReview), isTrue);
    expect(s(TaskStatus.needsReview, TaskStatus.inProgress), isTrue);
    expect(s(TaskStatus.needsReview, TaskStatus.practiceReported), isTrue);
    // No skipping ahead, no going back.
    expect(s(TaskStatus.upcoming, TaskStatus.submittedForReview), isFalse);
    expect(s(TaskStatus.practiceReported, TaskStatus.inProgress), isFalse);
    expect(s(TaskStatus.submittedForReview, TaskStatus.practiceReported), isFalse);
  });

  test('the teacher can verify or cancel any open task, and nothing else', () {
    bool t(TaskStatus a, TaskStatus b) => canTransition(a, b, TaskActor.teacher);
    for (final from in [
      TaskStatus.upcoming,
      TaskStatus.inProgress,
      TaskStatus.practiceReported,
      TaskStatus.submittedForReview,
      TaskStatus.needsReview,
    ]) {
      expect(t(from, TaskStatus.completed), isTrue, reason: '$from');
      expect(t(from, TaskStatus.cancelled), isTrue, reason: '$from');
    }
    expect(t(TaskStatus.practiceReported, TaskStatus.needsReview), isTrue);
    expect(t(TaskStatus.needsReview, TaskStatus.needsReview), isFalse);
    expect(t(TaskStatus.upcoming, TaskStatus.practiceReported), isFalse);
    expect(t(TaskStatus.upcoming, TaskStatus.inProgress), isFalse);
  });

  test('verification result maps to a status; only "passed" completes', () {
    expect(statusForVerification(verificationPassed), TaskStatus.completed);
    expect(statusForVerification(verificationNeedsImprovement), TaskStatus.needsReview);
    expect(statusForVerification('anything else'), TaskStatus.needsReview);
  });

  test('labels are distinct', () {
    expect(all.map(taskStatusLabel).toSet(), hasLength(all.length));
    expect(TaskType.values.map(taskTypeLabel).toSet(), hasLength(TaskType.values.length));
  });
}
