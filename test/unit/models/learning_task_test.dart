import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningTask model', () {
    final json = {
      'centerId': 'center-1',
      'planId': 'plan-1',
      'studentId': 'student-1',
      'teacherId': 'teacher-1',
      'taskType': 'recentRevision',
      'surah': 114,
      'startAyah': 1,
      'endAyah': 6,
      'assignedDate': 1700000000000,
      'dueDate': 2000000000000, // 2033, future relative to now
      'priority': 'medium',
      'teacherInstructions': 'راجع سورة الناس',
      'status': 'upcoming',
      'selfReportedPractice': null,
      'teacherVerification': null,
      'completionMetadata': null,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final task = LearningTask.fromJson('task-1', json);
      expect(task.taskId, 'task-1');
      expect(task.studentId, 'student-1');
      expect(task.taskType, TaskType.recentRevision);
      expect(task.surah, 114);
      expect(task.status, TaskStatus.upcoming);
      expect(task.isVerified, isFalse);
      expect(task.isOverdue, isFalse); // due date in future

      final back = task.toJson();
      expect(back['taskType'], 'recentRevision');
      expect(back['status'], 'upcoming');
    });

    test('isOverdue true when past due and not completed/cancelled', () {
      final overdue = LearningTask.fromJson('t', {...json, 'status': 'inProgress', 'dueDate': 1000});
      expect(overdue.isOverdue, isTrue);

      final completed = LearningTask.fromJson('t', {...json, 'status': 'completed', 'dueDate': 1000});
      expect(completed.isOverdue, isFalse);
    });

    test('selfReportedPractice distinct from teacherVerification', () {
      final withPractice = LearningTask.fromJson('t', {
        ...json,
        'selfReportedPractice': {
          'reportedAt': 1700000000000,
          'note': 'Practiced at home',
          'reflection': 'Felt confident',
        },
      });
      expect(withPractice.selfReportedPractice, isNotNull);
      expect(withPractice.selfReportedPractice!.reflection, 'Felt confident');
      expect(withPractice.isVerified, isFalse);

      final withVerification = LearningTask.fromJson('t', {
        ...json,
        'teacherVerification': {
          'verifiedAt': 1700000000000,
          'verifiedBy': 'teacher-1',
          'result': 'passed',
          'feedback': 'Well done',
        },
      });
      expect(withVerification.isVerified, isTrue);
      expect(withVerification.teacherVerification!.result, 'passed');
    });
  });

  group('Session model', () {
    final json = {
      'centerId': 'center-1',
      'circleId': 'circle-1',
      'scheduleId': 'schedule-1',
      'teacherId': 'teacher-1',
      'date': 1700000000000,
      'startTime': '08:00',
      'endTime': '10:00',
      'status': 'inProgress',
      'studentCount': 20,
      'attendanceCompletedCount': 18,
      'assessmentCompletedCount': 5,
      'isLocallyComplete': true,
      'serverConfirmedAt': null,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final session = Session.fromJson('session-1', json);
      expect(session.sessionId, 'session-1');
      expect(session.status, SessionStatus.inProgress);
      expect(session.studentCount, 20);
      expect(session.attendanceCompletedCount, 18);
      expect(session.assessmentCompletedCount, 5);
      expect(session.isLocallyComplete, isTrue);
      expect(session.isServerConfirmed, isFalse);
      expect(session.attendanceCompletionRate, 18 / 20);

      final back = session.toJson();
      expect(back['status'], 'inProgress');
      expect(back['isLocallyComplete'], isTrue);
    });

    test('isServerConfirmed true when serverConfirmedAt set', () {
      final confirmed = Session.fromJson('s', {...json, 'serverConfirmedAt': 1700000000000});
      expect(confirmed.isServerConfirmed, isTrue);
    });

    test('attendanceCompletionRate zero when no students', () {
      final empty = Session.fromJson('s', {...json, 'studentCount': 0, 'attendanceCompletedCount': 0});
      expect(empty.attendanceCompletionRate, 0);
    });
  });
}
