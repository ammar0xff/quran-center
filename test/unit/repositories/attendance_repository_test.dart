import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/repositories/attendance_repository.dart';
import 'package:quran_center/data/repositories/impl/attendance_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/audit_repository_impl.dart';

Attendance _record({
  String session = 'sess1',
  String student = 'stu1',
  AttendanceStatus status = AttendanceStatus.absent,
  String by = 'teacher1',
}) =>
    Attendance(
      attendanceId: attendanceDocId(session, student),
      centerId: 'center-1',
      sessionId: session,
      studentId: student,
      status: status,
      recordedBy: by,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  late FakeFirestoreDataSource fake;
  late AttendanceRepositoryImpl repo;
  late AuditRepositoryImpl audit;
  var tick = 0;

  setUp(() {
    fake = FakeFirestoreDataSource();
    tick = 0;
    repo = AttendanceRepositoryImpl(
      fake,
      clock: () => DateTime(2026, 11, 2, 9, 0, tick++),
    );
    audit = AuditRepositoryImpl(fake);
  });

  group('record', () {
    test('stores under the deterministic id', () async {
      await repo.record(_record());
      expect(await fake.getDoc('attendance/sess1_stu1'), isNotNull);
    });

    test('identical re-record is an idempotent no-op', () async {
      await repo.record(_record());
      await repo.record(_record());
      expect(await repo.getBySession('sess1'), hasLength(1));
    });

    test('different data for an existing record is rejected', () async {
      await repo.record(_record(status: AttendanceStatus.absent));
      expect(
        () => repo.record(_record(status: AttendanceStatus.present)),
        throwsA(isA<DuplicateAttendanceException>()),
      );
      final stored = (await repo.getBySession('sess1')).single;
      expect(stored.status, AttendanceStatus.absent);
    });

    test('queries by session, student and center', () async {
      await repo.record(_record(session: 's1', student: 'a'));
      await repo.record(_record(session: 's1', student: 'b'));
      await repo.record(_record(session: 's2', student: 'a'));
      expect(await repo.getBySession('s1'), hasLength(2));
      expect(await repo.getByStudent('a'), hasLength(2));
      expect(await repo.getByCenter('center-1'), hasLength(3));
    });
  });

  group('correct', () {
    test('updates status, keeps original, and writes an audit entry', () async {
      await repo.record(_record(status: AttendanceStatus.absent));

      await repo.correct(
        sessionId: 'sess1',
        studentId: 'stu1',
        newStatus: AttendanceStatus.excused,
        actorId: 'director1',
        actorRole: 'director',
        reason: 'medical note',
      );

      final updated = (await repo.getBySession('sess1')).single;
      expect(updated.status, AttendanceStatus.excused);
      expect(updated.correctionMetadata, isNotNull);
      expect(updated.correctionMetadata!.originalStatus, AttendanceStatus.absent);
      expect(updated.correctionMetadata!.correctedBy, 'director1');
      expect(updated.correctionMetadata!.reason, 'medical note');

      final logs = await audit.getForEntity('attendance', 'sess1_stu1');
      expect(logs, hasLength(1));
      expect(logs.single.action, 'correct_attendance');
      expect(logs.single.actorUserId, 'director1');
      expect(logs.single.previousValue!['status'], 'absent');
      expect(logs.single.newValue!['status'], 'excused');
      expect(logs.single.reason, 'medical note');
    });

    test('a second correction keeps the very first original status', () async {
      await repo.record(_record(status: AttendanceStatus.absent));
      Future<void> fix(AttendanceStatus s, String why) => repo.correct(
            sessionId: 'sess1',
            studentId: 'stu1',
            newStatus: s,
            actorId: 'director1',
            actorRole: 'director',
            reason: why,
          );

      await fix(AttendanceStatus.late, 'arrived late');
      await fix(AttendanceStatus.present, 'on second thought');

      final rec = (await repo.getBySession('sess1')).single;
      expect(rec.status, AttendanceStatus.present);
      expect(rec.correctionMetadata!.originalStatus, AttendanceStatus.absent);
      expect(await audit.getForEntity('attendance', 'sess1_stu1'), hasLength(2));
    });

    test('rejects a blank reason and changes nothing', () async {
      await repo.record(_record(status: AttendanceStatus.absent));
      await expectLater(
        repo.correct(
          sessionId: 'sess1',
          studentId: 'stu1',
          newStatus: AttendanceStatus.present,
          actorId: 'd',
          actorRole: 'director',
          reason: '  ',
        ),
        throwsA(isA<AttendanceCorrectionException>().having(
            (e) => e.error, 'error', CorrectionError.reasonRequired)),
      );
      expect((await repo.getBySession('sess1')).single.status,
          AttendanceStatus.absent);
      expect(await audit.getForEntity('attendance', 'sess1_stu1'), isEmpty);
    });

    test('rejects a no-op correction', () async {
      await repo.record(_record(status: AttendanceStatus.present));
      await expectLater(
        repo.correct(
          sessionId: 'sess1',
          studentId: 'stu1',
          newStatus: AttendanceStatus.present,
          actorId: 'd',
          actorRole: 'director',
          reason: 'x',
        ),
        throwsA(isA<AttendanceCorrectionException>()
            .having((e) => e.error, 'error', CorrectionError.sameStatus)),
      );
    });

    test('rejects correcting a record that does not exist', () async {
      await expectLater(
        repo.correct(
          sessionId: 'nope',
          studentId: 'nope',
          newStatus: AttendanceStatus.present,
          actorId: 'd',
          actorRole: 'director',
          reason: 'x',
        ),
        throwsA(isA<AttendanceCorrectionException>()),
      );
      expect(await fake.query('audit_logs', where: []), isEmpty);
    });
  });

  group('commitBatch atomicity (fake)', () {
    test('a failing update leaves no partial writes', () async {
      await expectLater(
        fake.commitBatch([
          const BatchOp.set('things/new', {'a': 1}),
          const BatchOp.update('things/missing', {'a': 2}),
        ]),
        throwsStateError,
      );
      expect(await fake.getDoc('things/new'), isNull);
    });
  });
}
