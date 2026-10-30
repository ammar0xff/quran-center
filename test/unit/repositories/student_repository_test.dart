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

    test('createStudent with an actor writes the student and its audit entry together', () async {
      await repo.createStudent(
        Student(
          studentId: 'stu-aud', centerId: 'center-1', fullName: 'طالب جديد',
          accountMode: AccountMode.none, enrollmentStatus: EnrollmentStatus.active,
          educationalLevel: 'مبتدئ',
          createdAt: DateTime(2026), updatedAt: DateTime(2026),
        ),
        actorId: 'dir-1',
        actorRole: 'director',
      );
      final stored = (await fake.getDoc('students/stu-aud'))!;
      expect(stored['createdBy'], 'dir-1');
      final audit = (await fake.query('audit_logs', where: [])).single;
      expect(audit['action'], 'create_student');
      expect(audit['entityId'], 'stu-aud');
      expect(audit['actorUserId'], 'dir-1');
      expect(audit['centerId'], 'center-1');
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
      await fake.setDoc('student_admin_notes/student-1', {
        'centerId': 'center-1', 'studentId': 'student-1', 'note': 'ملاحظة سابقة',
      });

      await repo.archiveStudent('student-1',
          actorId: 'director-1', actorRole: 'director', reason: 'غادر');

      final stored = (await fake.getDoc('students/student-1'))!;
      expect(stored['enrollmentStatus'], 'archived');
      expect(stored['updatedBy'], 'director-1');
      expect(stored['fullName'], 'أحمد محمد'); // nothing deleted
      expect(await repo.getAdminNote('student-1', centerId: 'center-1'),
          'ملاحظة سابقة'); // not overwritten by the reason

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

    test('updateProfile saves only what changed and audits previous/new values',
        () async {
      await seedStudent(fullName: 'أحمد محمد');
      final saved = await repo.updateProfile('student-1',
          actorId: 'director-1',
          actorRole: 'director',
          fullName: '  أحمد محمد  ',
          preferredName: ' أحمودي ',
          educationalLevel: 'متقدم',
          adminNotes: '');

      expect(saved, isTrue);
      final stored = (await fake.getDoc('students/student-1'))!;
      expect(stored['fullName'], 'أحمد محمد');
      expect(stored['preferredName'], 'أحمودي');
      expect(stored['educationalLevel'], 'متقدم');
      expect(stored['enrollmentStatus'], 'active'); // untouched
      expect(stored['updatedBy'], 'director-1');

      final audit = (await fake.query('audit_logs', where: [])).single;
      expect(audit['action'], 'update_student');
      expect((audit['newValue'] as Map).keys.toSet(),
          {'preferredName', 'educationalLevel'}); // name unchanged
      expect((audit['previousValue'] as Map)['educationalLevel'], 'مبتدئ');
    });

    test('updateProfile with no change writes nothing and no audit', () async {
      await seedStudent(fullName: 'أحمد محمد');
      final saved = await repo.updateProfile('student-1',
          actorId: 'd',
          actorRole: 'director',
          fullName: 'أحمد محمد',
          educationalLevel: 'مبتدئ');
      expect(saved, isFalse);
      expect(await fake.query('audit_logs', where: []), isEmpty);
    });

    test('updateProfile rejects blank required fields and unknown students',
        () async {
      await seedStudent();
      await expectLater(
          repo.updateProfile('student-1',
              actorId: 'd', actorRole: 'director', fullName: '  ', educationalLevel: 'x'),
          throwsArgumentError);
      await expectLater(
          repo.updateProfile('student-1',
              actorId: 'd', actorRole: 'director', fullName: 'x', educationalLevel: ''),
          throwsArgumentError);
      await expectLater(
          repo.updateProfile('ghost',
              actorId: 'd', actorRole: 'director', fullName: 'x', educationalLevel: 'y'),
          throwsStateError);
      expect(await fake.query('audit_logs', where: []), isEmpty);
    });

    test('the staff note lives in its own document, never in the student document',
        () async {
      await seedStudent();
      await repo.updateProfile('student-1',
          actorId: 'd', actorRole: 'director', fullName: 'أحمد محمد',
          educationalLevel: 'مبتدئ', adminNotes: '  سري للإدارة ');
      expect(await repo.getAdminNote('student-1', centerId: 'center-1'), 'سري للإدارة');
      final student = (await fake.getDoc('students/student-1'))!;
      expect(student.containsKey('adminNotes'), isFalse);
      expect('$student', isNot(contains('سري للإدارة')));
      final audit = (await fake.query('audit_logs', where: [])).single;
      expect((audit['newValue'] as Map)['adminNotes'], 'سري للإدارة');
    });

    test('a null note leaves it alone; a blank one clears it; another center sees nothing',
        () async {
      await seedStudent();
      await repo.updateProfile('student-1', actorId: 'd', actorRole: 'director',
          fullName: 'أحمد محمد', educationalLevel: 'مبتدئ', adminNotes: 'ملاحظة');
      await repo.updateProfile('student-1', actorId: 'd', actorRole: 'director',
          fullName: 'اسم جديد', educationalLevel: 'مبتدئ'); // adminNotes omitted
      expect(await repo.getAdminNote('student-1', centerId: 'center-1'), 'ملاحظة');
      expect(await repo.getAdminNote('student-1', centerId: 'center-2'), isNull);

      await repo.updateProfile('student-1', actorId: 'd', actorRole: 'director',
          fullName: 'اسم جديد', educationalLevel: 'مبتدئ', adminNotes: '  ');
      expect(await repo.getAdminNote('student-1', centerId: 'center-1'), isNull);
    });

    test('archiving ends the circle enrolment (kept as history) and clears teacher and circle',
        () async {
      await seedStudent(teacherIds: ['t1']);
      await fake.updateDoc('students/student-1', {'currentCircleId': 'cA'});
      await fake.setDoc('enrollments/e1', {
        'centerId': 'center-1', 'studentId': 'student-1', 'circleId': 'cA',
        'teacherId': 't1', 'startDate': 1700000000000, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
      await fake.setDoc('enrollments/e0', {
        'centerId': 'center-1', 'studentId': 'student-1', 'circleId': 'old',
        'startDate': 1600000000000, 'status': 'transferred',
        'createdAt': 1600000000000, 'updatedAt': 1600000000000,
      });

      await repo.archiveStudent('student-1', actorId: 'd', actorRole: 'director');

      final e1 = (await fake.getDoc('enrollments/e1'))!;
      expect(e1['status'], 'withdrawn');
      expect(e1['circleId'], 'cA'); // history intact
      expect(e1['changedBy'], 'd');
      expect((await fake.getDoc('enrollments/e0'))!['status'], 'transferred'); // untouched
      final s = (await fake.getDoc('students/student-1'))!;
      expect(s['assignedTeacherIds'], isEmpty);
      expect(s['currentCircleId'], isNull);
      final audit = (await fake.query('audit_logs', where: [])).single;
      expect((audit['previousValue'] as Map)['circleIds'], ['cA']);
    });

    test('archiving gives the seat back to the circle', () async {
      await seedStudent();
      await fake.setDoc('circles/cA', {
        'centerId': 'center-1', 'name': 'A', 'educationalLevel': 'x', 'maxCapacity': 5,
        'activeCount': 3, 'locationOrMode': 'onsite', 'weeklySchedule': [],
        'sessionDurationMinutes': 60, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
      await fake.setDoc('enrollments/e1', {
        'centerId': 'center-1', 'studentId': 'student-1', 'circleId': 'cA',
        'startDate': 1700000000000, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
      await repo.archiveStudent('student-1', actorId: 'd', actorRole: 'director');
      expect((await fake.getDoc('circles/cA'))!['activeCount'], 2);
    });

    test('reinstating does not touch enrolments or invent a circle', () async {
      await seedStudent(status: EnrollmentStatus.archived);
      await repo.reinstateStudent('student-1', actorId: 'd', actorRole: 'director');
      final s = (await fake.getDoc('students/student-1'))!;
      expect(s['enrollmentStatus'], 'active');
      expect(s['currentCircleId'], isNull);
      expect(await fake.query('enrollments', where: []), isEmpty);
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

      final result = await repo.getStudentsByTeacher('t1', centerId: 'center-1');
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
