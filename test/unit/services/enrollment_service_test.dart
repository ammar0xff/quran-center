import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/enrollment_planner.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/services/enrollment_service.dart';

final _start = DateTime(2026, 11, 2);

Future<void> _seed(FakeFirestoreDataSource s) async {
  await s.setDoc('students/s1', {
    'centerId': 'c1',
    'fullName': 'طالب',
    'accountMode': 'none',
    'enrollmentStatus': 'active',
    'assignedTeacherIds': <String>[],
    'educationalLevel': 'x',
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
  });
  Future<void> circle(String id, {int cap = 2, String? teacher, String status = 'active', String center = 'c1'}) =>
      s.setDoc('circles/$id', {
        'centerId': center,
        'name': id,
        'educationalLevel': 'x',
        'assignedTeacherId': teacher,
        'maxCapacity': cap,
        'locationOrMode': 'onsite',
        'weeklySchedule': [],
        'sessionDurationMinutes': 60,
        'status': status,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await circle('A', teacher: 'tA');
  await circle('B', teacher: 'tB');
  await circle('full', cap: 1, teacher: 'tF');
  await circle('old', status: 'archived');
  await circle('foreign', center: 'c2');
  // 'full' already has its one student.
  await s.setDoc('enrollments/other', {
    'centerId': 'c1', 'studentId': 'someone', 'circleId': 'full',
    'startDate': 1700000000000, 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

void main() {
  _raceTests();
  late FakeFirestoreDataSource store;
  late EnrollmentService service;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    service = EnrollmentService(store, clock: () => DateTime(2026, 11, 2, 9));
  });

  Future<void> assign(String circle, {String? reason}) => service.assign(
        centerId: 'c1',
        studentId: 's1',
        circleId: circle,
        actorId: 'dir-1',
        actorRole: 'director',
        startDate: _start,
        reason: reason,
      );

  test('first assignment creates the enrolment, sets the teacher, and audits', () async {
    final e = await service.assign(
      centerId: 'c1',
      studentId: 's1',
      circleId: 'A',
      actorId: 'dir-1',
      actorRole: 'director',
      startDate: _start,
    );
    expect(e.enrollmentId, 'enr_s1_A_20261102');
    expect(e.teacherId, 'tA');

    final stored = (await store.getDoc('enrollments/enr_s1_A_20261102'))!;
    expect(stored['status'], 'active');
    expect(stored['studentId'], 's1');
    expect(stored['circleId'], 'A');
    expect(stored['teacherId'], 'tA');

    final student = (await store.getDoc('students/s1'))!;
    expect(student['assignedTeacherIds'], ['tA']);
    expect(student['currentCircleId'], 'A');
    expect(student['updatedBy'], 'dir-1');

    final audit = await store.query('audit_logs', where: []);
    expect(audit.single['action'], 'assign_student');
    expect(audit.single['actorUserId'], 'dir-1');
    expect(audit.single['centerId'], 'c1');
    expect((audit.single['newValue'] as Map)['circleId'], 'A');
  });

  test('assigning to another circle transfers: old closed with history kept, teacher replaced', () async {
    await assign('A');
    await assign('B', reason: 'يناسبه الوقت');

    final old = (await store.getDoc('enrollments/enr_s1_A_20261102'))!;
    expect(old['status'], 'transferred');
    expect(old['changeReason'], 'يناسبه الوقت');
    expect(old['changedBy'], 'dir-1');
    expect(old['endDate'], isNotNull);
    expect(old['circleId'], 'A'); // history intact

    expect((await store.getDoc('enrollments/enr_s1_B_20261102'))!['status'], 'active');
    expect((await store.getDoc('students/s1'))!['assignedTeacherIds'], ['tB']);
    expect((await store.getDoc('students/s1'))!['currentCircleId'], 'B');

    final actives = (await store.query('enrollments', where: []))
        .where((e) => e['studentId'] == 's1' && e['status'] == 'active');
    expect(actives, hasLength(1));

    final actions = (await store.query('audit_logs', where: [])).map((a) => a['action']).toSet();
    expect(actions, {'assign_student', 'transfer_student'});
  });

  test('a default reason is recorded when none is given for a transfer', () async {
    await assign('A');
    await assign('B');
    expect((await store.getDoc('enrollments/enr_s1_A_20261102'))!['changeReason'], 'نقل إلى حلقة أخرى');
  });

  test('re-submitting the same assignment is rejected, not duplicated', () async {
    await assign('A');
    await expectLater(
      assign('A'),
      throwsA(isA<EnrollmentAssignmentException>()
          .having((e) => e.error, 'error', AssignmentError.alreadyInCircle)),
    );
    final all = (await store.query('enrollments', where: []))
        .where((e) => e['studentId'] == 's1');
    expect(all, hasLength(1));
  });

  test('a full circle is refused and nothing is written', () async {
    await expectLater(
      assign('full'),
      throwsA(isA<EnrollmentAssignmentException>()
          .having((e) => e.error, 'error', AssignmentError.circleFull)),
    );
    expect((await store.getDoc('students/s1'))!['assignedTeacherIds'], isEmpty);
    expect(await store.query('audit_logs', where: []), isEmpty);
  });

  test('an archived circle is refused', () async {
    await expectLater(
      assign('old'),
      throwsA(isA<EnrollmentAssignmentException>()
          .having((e) => e.error, 'error', AssignmentError.circleNotActive)),
    );
  });

  test('other-center and missing records look the same: not found', () async {
    await expectLater(assign('foreign'), throwsA(isA<EnrollmentAssignmentException>()));
    await expectLater(assign('nope'), throwsA(isA<EnrollmentAssignmentException>()));
    await expectLater(
      service.assign(
        centerId: 'c2', // acting in the wrong center for this student
        studentId: 's1',
        circleId: 'foreign',
        actorId: 'x',
        actorRole: 'director',
        startDate: _start,
      ),
      throwsA(isA<EnrollmentAssignmentException>()),
    );
    expect(await store.query('audit_logs', where: []), isEmpty);
  });

  test('a failed atomic write leaves no partial change', () async {
    final broken = _FailingBatchStore();
    await _seed(broken);
    final svc = EnrollmentService(broken, clock: () => DateTime(2026, 11, 2, 9));
    await expectLater(
      svc.assign(
        centerId: 'c1',
        studentId: 's1',
        circleId: 'A',
        actorId: 'dir-1',
        actorRole: 'director',
        startDate: _start,
      ),
      throwsStateError,
    );
    expect(await broken.getDoc('enrollments/enr_s1_A_20261102'), isNull);
    expect(await broken.query('audit_logs', where: []), isEmpty);
    expect((await broken.getDoc('students/s1'))!['assignedTeacherIds'], isEmpty);
  });
}


void _raceTests() {
  group('capacity and counter', () {
    late FakeFirestoreDataSource store;
    late EnrollmentService service;

    setUp(() async {
      store = FakeFirestoreDataSource();
      await _seed(store);
      for (final id in ['s2', 's3']) {
        await store.setDoc('students/$id', {
          'centerId': 'c1', 'fullName': id, 'accountMode': 'none', 'enrollmentStatus': 'active',
          'assignedTeacherIds': <String>[], 'educationalLevel': 'x',
          'createdAt': 1700000000000, 'updatedAt': 1700000000000,
        });
      }
      service = EnrollmentService(store, clock: () => DateTime(2026, 11, 2, 9));
    });

    Future<void> assign(String student, String circle) => service.assign(
          centerId: 'c1', studentId: student, circleId: circle,
          actorId: 'dir-1', actorRole: 'director', startDate: DateTime(2026, 11, 2),
        );

    Future<int> count(String circle) async =>
        ((await store.getDoc('circles/$circle'))!['activeCount'] as int?) ?? 0;

    test('the circle counter follows assignments and transfers', () async {
      await assign('s1', 'A');
      expect(await count('A'), 1);
      await assign('s2', 'A');
      expect(await count('A'), 2);
      await assign('s1', 'B'); // transfer out of A
      expect(await count('A'), 1);
      expect(await count('B'), 1);
    });

    test('two directors taking the last seat at the same moment: exactly one wins', () async {
      // Circle A holds 2; fill one seat, then race s2 and s3 for the last one.
      await store.updateDoc('circles/A', {'maxCapacity': 2});
      await assign('s1', 'A');
      final results = await Future.wait([
        assign('s2', 'A').then((_) => 'ok', onError: (_) => 'full'),
        assign('s3', 'A').then((_) => 'ok', onError: (_) => 'full'),
      ]);
      expect(results.where((r) => r == 'ok'), hasLength(1));
      expect(results.where((r) => r == 'full'), hasLength(1));
      expect(await count('A'), 2);
      final active = (await store.query('enrollments', where: []))
          .where((e) => e['circleId'] == 'A' && e['status'] == 'active');
      expect(active, hasLength(2));
    });

    test('a refused assignment changes no counter', () async {
      await store.updateDoc('circles/A', {'maxCapacity': 1, 'activeCount': 1});
      await expectLater(assign('s2', 'A'), throwsA(isA<EnrollmentAssignmentException>()));
      expect(await count('A'), 1);
      expect(await count('B'), 0);
    });
  });
}

class _FailingBatchStore extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    throw StateError('network down');
  }
}
