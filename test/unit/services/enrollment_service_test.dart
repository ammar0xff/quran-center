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

class _FailingBatchStore extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    throw StateError('network down');
  }
}
