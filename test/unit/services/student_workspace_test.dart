import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/services/student_workspace.dart';

final _now = DateTime(2026, 11, 10, 9);

Future<void> _seed(FakeFirestoreDataSource s) async {
  Future<void> task(String id, String status, {String student = 's1', String center = 'c1'}) =>
      s.setDoc('learning_tasks/$id', {
        'centerId': center, 'planId': 'plan_${student}_t1', 'studentId': student,
        'teacherId': 't1', 'taskType': 'recentRevision', 'surah': 112, 'startAyah': 1,
        'endAyah': 4, 'assignedDate': 1700000000000, 'dueDate': 1800000000000,
        'teacherInstructions': '', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await task('up', 'upcoming');
  await task('prog', 'inProgress');
  await task('rep', 'practiceReported');
  await task('redo', 'needsReview');
  await task('done', 'completed');
  await task('cancelled', 'cancelled');
  await task('others', 'upcoming', student: 's2');
  await task('foreign', 'upcoming', center: 'c2');
}

void main() {
  late FakeFirestoreDataSource store;
  late StudentWorkspace ws;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    ws = StudentWorkspace(store, clock: () => _now);
  });

  Future<String> status(String id) async => (await store.getDoc('learning_tasks/$id'))!['status'] as String;

  test('a student sees only their own tasks', () async {
    final ids = (await ws.tasks('c1', 's1')).map((t) => t.taskId).toSet();
    expect(ids, {'up', 'prog', 'rep', 'redo', 'done', 'cancelled'});
  });

  group('start', () {
    test('moves an upcoming task to in progress', () async {
      await ws.start('c1', 's1', 'up');
      expect(await status('up'), 'inProgress');
    });
    test('not from any other state', () async {
      for (final id in ['prog', 'rep', 'done', 'cancelled']) {
        await expectLater(ws.start('c1', 's1', id), throwsA(isA<StudentActionException>()), reason: id);
      }
    });
  });

  group('reportPractice', () {
    test('is recorded as a claim and does NOT complete the task', () async {
      await ws.reportPractice('c1', 's1', 'prog', reflection: '  تدربت عشر مرات ');
      final t = (await store.getDoc('learning_tasks/prog'))!;
      expect(t['status'], 'practiceReported');
      final claim = t['selfReportedPractice'] as Map;
      expect(claim['reflection'], 'تدربت عشر مرات');
      expect(claim['reportedAt'], isNotNull);
      expect(t.containsKey('teacherVerification'), isFalse);
      expect(t.containsKey('completionMetadata'), isFalse);
    });
    test('works straight from upcoming and again after a return for review', () async {
      await ws.reportPractice('c1', 's1', 'up');
      await ws.reportPractice('c1', 's1', 'redo');
      expect(await status('up'), 'practiceReported');
      expect(await status('redo'), 'practiceReported');
    });
    test('not twice, and not on finished tasks', () async {
      for (final id in ['rep', 'done', 'cancelled']) {
        await expectLater(ws.reportPractice('c1', 's1', id), throwsA(isA<StudentActionException>()), reason: id);
      }
    });
  });

  group('submitForReview', () {
    test('only after practice was reported', () async {
      await ws.submitForReview('c1', 's1', 'rep');
      expect(await status('rep'), 'submittedForReview');
      await expectLater(ws.submitForReview('c1', 's1', 'up'), throwsA(isA<StudentActionException>()));
      await expectLater(ws.submitForReview('c1', 's1', 'prog'), throwsA(isA<StudentActionException>()));
    });
  });

  test('no other student\'s or center\'s task can be touched', () async {
    await expectLater(ws.start('c1', 's1', 'others'), throwsA(isA<StudentActionException>()));
    await expectLater(ws.start('c1', 's1', 'foreign'), throwsA(isA<StudentActionException>()));
    await expectLater(ws.start('c1', 's1', 'nope'), throwsA(isA<StudentActionException>()));
    expect(await status('others'), 'upcoming');
    expect(await status('foreign'), 'upcoming');
  });

  test('a student has no way to complete a task', () async {
    // There is no completing method; every path leaves 'completed' unreachable.
    await ws.start('c1', 's1', 'up');
    await ws.reportPractice('c1', 's1', 'up');
    await ws.submitForReview('c1', 's1', 'up');
    expect(await status('up'), 'submittedForReview');
    await expectLater(ws.reportPractice('c1', 's1', 'up'), throwsA(isA<StudentActionException>()));
  });
}
