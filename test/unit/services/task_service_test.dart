import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/services/task_service.dart';

final _now = DateTime(2026, 11, 10, 9);

Future<void> _seed(FakeFirestoreDataSource s) async {
  for (final (id, teacher) in [('s1', 't1'), ('s2', 't2')]) {
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'c1', 'studentId': id, 'circleId': 'cA', 'teacherId': teacher,
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('enrollments/e_old', {
    'centerId': 'c1', 'studentId': 's3', 'circleId': 'cA', 'teacherId': 't1',
    'startDate': 1700000000000, 'status': 'transferred',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

void main() {
  late FakeFirestoreDataSource store;
  late TaskService svc;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    svc = TaskService(store, clock: () => _now);
  });

  Future<void> assign({
    String id = 'task1',
    String student = 's1',
    String teacher = 't1',
    int surah = 112,
    int start = 1,
    int end = 4,
    DateTime? due,
    String? priority,
    String? instructions = '  راجع جيدًا ',
  }) =>
      svc.assign(
        centerId: 'c1',
        teacherId: teacher,
        studentId: student,
        taskId: id,
        type: TaskType.recentRevision,
        surah: surah,
        startAyah: start,
        endAyah: end,
        dueDate: due ?? DateTime(2026, 11, 17),
        instructions: instructions,
        priority: priority,
      );

  group('assign', () {
    test('creates an upcoming task with no claim or verification, plus the plan', () async {
      await assign(priority: 'high');
      final t = (await store.getDoc('learning_tasks/task1'))!;
      expect(t['status'], 'upcoming');
      expect(t['teacherId'], 't1');
      expect(t['studentId'], 's1');
      expect(t['planId'], 'plan_s1_t1');
      expect(t['surah'], 112);
      expect(t['teacherInstructions'], 'راجع جيدًا');
      expect(t['priority'], 'high');
      expect(t.containsKey('selfReportedPractice'), isFalse);
      expect(t.containsKey('teacherVerification'), isFalse);
      expect(t['assignedDate'], isA<Timestamp>());

      final plan = (await store.getDoc('learning_plans/plan_s1_t1'))!;
      expect(plan['responsibleTeacherId'], 't1');
      expect(plan['studentId'], 's1');
    });

    test('a second task reuses the plan; a retry rewrites the same task', () async {
      await assign();
      await assign(id: 'task2', start: 1, end: 2);
      await assign(); // same form retried
      expect(await store.query('learning_plans', where: []), hasLength(1));
      expect(await store.query('learning_tasks', where: []), hasLength(2));
    });

    test('only the teacher\'s own current students', () async {
      await expectLater(assign(student: 's2'), throwsA(isA<TaskException>())); // t2's student
      await expectLater(assign(student: 's3'), throwsA(isA<TaskException>())); // transferred away
      await expectLater(assign(student: 'ghost'), throwsA(isA<TaskException>()));
      expect(await store.query('learning_tasks', where: []), isEmpty);
      expect(await store.query('learning_plans', where: []), isEmpty);
    });

    test('invalid ranges, past due dates and bad priorities are refused', () async {
      await expectLater(assign(surah: 112, end: 5), throwsA(isA<TaskException>()));
      await expectLater(assign(start: 3, end: 2), throwsA(isA<TaskException>()));
      await expectLater(assign(surah: 0), throwsA(isA<TaskException>()));
      await expectLater(assign(due: DateTime(2026, 11, 9)), throwsA(isA<TaskException>()));
      await expectLater(assign(priority: 'urgent'), throwsA(isA<TaskException>()));
      expect(await store.query('learning_tasks', where: []), isEmpty);
      await assign(due: DateTime(2026, 11, 10)); // due today is fine
    });
  });

  group('verify', () {
    setUp(() async => assign());

    test('passed completes the task and records who verified it and when', () async {
      await svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'passed', feedback: ' ممتاز ');
      final t = (await store.getDoc('learning_tasks/task1'))!;
      expect(t['status'], 'completed');
      final v = t['teacherVerification'] as Map;
      expect(v['verifiedBy'], 't1');
      expect(v['result'], 'passed');
      expect(v['feedback'], 'ممتاز');
      expect(v['verifiedAt'], isA<Timestamp>());
      expect((t['completionMetadata'] as Map)['completedAt'], isNotNull);
    });

    test('nested timestamps read back as real dates', () async {
      await svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'passed');
      final decoded = firestoreConverter.decodeFromRead((await store.getDoc('learning_tasks/task1'))!);
      expect((decoded['teacherVerification'] as Map)['verifiedAt'], isA<DateTime>());
      final tasks = await svc.tasksForStudent('c1', 't1', 's1');
      expect(tasks.single.teacherVerification!.verifiedAt, _now);
      expect(tasks.single.isVerified, isTrue);
    });

    test('needs_improvement returns it for another attempt and does not complete it', () async {
      await svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'needs_improvement');
      final t = (await store.getDoc('learning_tasks/task1'))!;
      expect(t['status'], 'needsReview');
      expect((t['completionMetadata'] as Map).containsKey('completedAt'), isFalse);
    });

    test('a completed task cannot be verified again; unknown results and other teachers are refused', () async {
      await svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'passed');
      await expectLater(
          svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'needs_improvement'),
          throwsA(isA<TaskException>()));
      await expectLater(
          svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'great'),
          throwsA(isA<TaskException>()));
      await expectLater(
          svc.verify(centerId: 'c1', teacherId: 't2', taskId: 'task1', result: 'passed'),
          throwsA(isA<TaskException>()));
      await expectLater(
          svc.verify(centerId: 'c2', teacherId: 't1', taskId: 'task1', result: 'passed'),
          throwsA(isA<TaskException>()));
    });
  });

  group('cancel', () {
    setUp(() async => assign());

    test('needs a reason and keeps it', () async {
      await expectLater(
          svc.cancel(centerId: 'c1', teacherId: 't1', taskId: 'task1', reason: '  '),
          throwsA(isA<TaskException>()));
      await svc.cancel(centerId: 'c1', teacherId: 't1', taskId: 'task1', reason: ' تغيّرت الخطة ');
      final t = (await store.getDoc('learning_tasks/task1'))!;
      expect(t['status'], 'cancelled');
      expect((t['completionMetadata'] as Map)['reason'], 'تغيّرت الخطة');
      expect((t['completionMetadata'] as Map)['cancelledBy'], 't1');
    });

    test('a closed task cannot be cancelled', () async {
      await svc.verify(centerId: 'c1', teacherId: 't1', taskId: 'task1', result: 'passed');
      await expectLater(
          svc.cancel(centerId: 'c1', teacherId: 't1', taskId: 'task1', reason: 'x'),
          throwsA(isA<TaskException>()));
      expect((await store.getDoc('learning_tasks/task1'))!['status'], 'completed');
    });
  });

  test('listing is scoped to the teacher and newest first', () async {
    await assign(id: 'a');
    await store.setDoc('learning_tasks/foreign', {
      'centerId': 'c1', 'planId': 'plan_s2_t2', 'studentId': 's2', 'teacherId': 't2',
      'taskType': 'recentRevision', 'surah': 1, 'startAyah': 1, 'endAyah': 2,
      'assignedDate': 1, 'dueDate': 2, 'teacherInstructions': '', 'status': 'upcoming',
      'createdAt': 1, 'updatedAt': 1,
    });
    final mine = await svc.tasksForTeacher('c1', 't1');
    expect(mine.map((t) => t.taskId), ['a']);
    expect(await svc.tasksForStudent('c1', 't1', 's2'), isEmpty);
  });

  test('a failed atomic write leaves neither plan nor task', () async {
    final broken = _Failing();
    await _seed(broken);
    final s = TaskService(broken, clock: () => _now);
    await expectLater(
      s.assign(centerId: 'c1', teacherId: 't1', studentId: 's1', taskId: 'x',
          type: TaskType.newMemorization, surah: 1, startAyah: 1, endAyah: 2,
          dueDate: DateTime(2026, 11, 20)),
      throwsStateError,
    );
    expect(await broken.query('learning_tasks', where: []), isEmpty);
    expect(await broken.query('learning_plans', where: []), isEmpty);
  });
}

class _Failing extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async => throw StateError('down');
}
