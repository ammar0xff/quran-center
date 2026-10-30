import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/repositories/impl/student_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentRepositoryImpl (fake datasource)', () {
    late FakeFirestoreDataSource fake;
    late StudentRepositoryImpl repo;

    setUp(() {
      fake = FakeFirestoreDataSource();
      repo = StudentRepositoryImpl(fake);
    });

    Future<void> seedStudent({
      String id = 'student-1',
      String centerId = 'center-1',
      String fullName = 'أحمد محمد',
      AccountMode accountMode = AccountMode.none,
      EnrollmentStatus status = EnrollmentStatus.active,
      List<String> teacherIds = const [],
    }) async {
      await fake.setDoc('students/$id', {
        'centerId': centerId,
        'fullName': fullName,
        'accountMode': accountMode.toJson(),
        'enrollmentStatus': status.toJson(),
        'assignedTeacherIds': teacherIds,
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
    }

    test('getStudent returns null when not found', () async {
      expect(await repo.getStudent('missing'), isNull);
    });

    test('getStudent returns the stored student', () async {
      await seedStudent();
      final s = await repo.getStudent('student-1');
      expect(s, isNotNull);
      expect(s!.studentId, 'student-1');
      expect(s.fullName, 'أحمد محمد');
      expect(s.accountMode, AccountMode.none);
      expect(s.hasLogin, isFalse);
    });

    test('createStudent persists and is readable back', () async {
      await repo.createStudent(Student(
        studentId: 'student-new',
        centerId: 'center-1',
        fullName: 'سارة علي',
        accountMode: AccountMode.loginEnabled,
        authUserId: 'uid-new',
        enrollmentStatus: EnrollmentStatus.active,
        educationalLevel: 'متوسط',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ));

      final stored = await fake.getDoc('students/student-new');
      expect(stored, isNotNull);
      expect(stored!['fullName'], 'سارة علي');
      expect(stored['accountMode'], 'loginEnabled');
      expect(stored['authUserId'], 'uid-new');

      final readBack = await repo.getStudent('student-new');
      expect(readBack!.fullName, 'سارة علي');
      expect(readBack.hasLogin, isTrue);
      expect(readBack.authUserId, 'uid-new');
    });

    test('updateStudent updates fields and drops studentId', () async {
      await seedStudent(fullName: 'أحمد محمد');
      final Student original = (await repo.getStudent('student-1'))!;
      await repo.updateStudent(
        original.copyWith(fullName: 'أحمد متغير', educationalLevel: 'متوسط'),
      );

      final stored = await fake.getDoc('students/student-1');
      expect(stored, isNotNull);
      expect(stored!['fullName'], 'أحمد متغير');
      expect(stored['educationalLevel'], 'متوسط');
      expect(stored.containsKey('studentId'), isFalse);
    });

    test('archiveStudent archives, keeps the record and admin notes, and audits',
        () async {
      await seedStudent(status: EnrollmentStatus.active);
      await fake.updateDoc('students/student-1', {'adminNotes': 'ملاحظة سابقة'});

      await repo.archiveStudent('student-1',
          actorId: 'director-1', actorRole: 'director', reason: 'غادر');

      final stored = (await fake.getDoc('students/student-1'))!;
      expect(stored['enrollmentStatus'], 'archived');
      expect(stored['updatedBy'], 'director-1');
      expect(stored['fullName'], 'أحمد محمد'); // nothing deleted
      expect(stored['adminNotes'], 'ملاحظة سابقة'); // not overwritten by the reason

      final audit = await fake.query('audit_logs', where: []);
      expect(audit, hasLength(1));
      expect(audit.single['action'], 'archive_student');
      expect(audit.single['entityId'], 'student-1');
      expect(audit.single['centerId'], 'center-1');
      expect(audit.single['actorUserId'], 'director-1');
      expect(audit.single['actorRole'], 'director');
      expect(audit.single['previousValue'], {'enrollmentStatus': 'active'});
      expect(audit.single['newValue'], {'enrollmentStatus': 'archived'});
      expect(audit.single['reason'], 'غادر');
    });

    test('reinstateStudent restores active status and audits it', () async {
      await seedStudent(status: EnrollmentStatus.archived);
      await repo.reinstateStudent('student-1',
          actorId: 'director-1', actorRole: 'director');

      expect((await fake.getDoc('students/student-1'))!['enrollmentStatus'], 'active');
      final audit = await fake.query('audit_logs', where: []);
      expect(audit.single['action'], 'reinstate_student');
      expect(audit.single.containsKey('reason'), isFalse); // no blank reason stored
    });

    test('archiving a student that does not exist fails and writes no audit',
        () async {
      await expectLater(
        repo.archiveStudent('ghost', actorId: 'd', actorRole: 'director'),
        throwsStateError,
      );
      expect(await fake.query('audit_logs', where: []), isEmpty);
    });

    test('getStudentsByCenter filters by centerId', () async {
      await seedStudent(id: 's1', centerId: 'center-1', fullName: 'أحد');
      await seedStudent(id: 's2', centerId: 'center-2', fullName: 'اثنان');

      final result = await repo.getStudentsByCenter('center-1');
      expect(result, hasLength(1));
      expect(result.first.fullName, 'أحد');
    });

    test('getStudentsByTeacher uses arrayContains on assignedTeacherIds', () async {
      await seedStudent(id: 's1', teacherIds: ['t1', 't2'], fullName: 'أحد');
      await seedStudent(id: 's2', teacherIds: ['t3'], fullName: 'اثنان');

      final result = await repo.getStudentsByTeacher('t1');
      expect(result, hasLength(1));
      expect(result.first.fullName, 'أحد');
    });

    test('watchStudentsByCenter emits matching students as a stream', () async {
      await seedStudent(id: 's1', centerId: 'center-1', fullName: 'أحد');
      await seedStudent(id: 's2', centerId: 'center-2', fullName: 'اثنان');

      final stream = repo.watchStudentsByCenter('center-1');
      final emitted = await stream.first;
      expect(emitted, hasLength(1));
      expect(emitted.first.fullName, 'أحد');
    });
  });
}
