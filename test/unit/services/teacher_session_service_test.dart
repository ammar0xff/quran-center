import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';

final _today = DateTime(2026, 11, 10, 9);
int _ms(DateTime d) => d.millisecondsSinceEpoch;

Future<void> _seed(FakeFirestoreDataSource s) async {
  await s.setDoc('circles/cA', {
    'centerId': 'c1', 'name': 'حلقة الفجر', 'educationalLevel': 'x', 'maxCapacity': 10,
    'locationOrMode': 'onsite', 'weeklySchedule': [], 'sessionDurationMinutes': 60,
    'status': 'active', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  Future<void> session(String id, String status,
          {String teacher = 't1', String center = 'c1', DateTime? date}) =>
      s.setDoc('schedules/$id', {
        'centerId': center, 'circleId': 'cA', 'teacherId': teacher,
        'date': _ms(date ?? DateTime(2026, 11, 10)), 'startTime': '08:00', 'endTime': '09:00',
        'locationOrMode': 'onsite', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('sched', 'scheduled');
  await session('live', 'inProgress');
  await session('done', 'completed');
  await session('tomorrow', 'scheduled', date: DateTime(2026, 11, 11));
  await session('theirs', 'inProgress', teacher: 't2');
  await session('foreign', 'inProgress', center: 'c2');

  Future<void> student(String id, String name, List<String> teachers) =>
      s.setDoc('students/$id', {
        'centerId': 'c1', 'fullName': name, 'accountMode': 'none', 'enrollmentStatus': 'active',
        'assignedTeacherIds': teachers, 'educationalLevel': 'x',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await student('s1', 'بسمة', ['t1']);
  await student('s2', 'أحمد', ['t1']);
  await student('s3', 'ليس طالبي', ['t2']);
  await student('s4', 'انتقل', ['t1']); // assigned but no active enrolment here
  for (final id in ['s1', 's2']) {
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'c1', 'studentId': id, 'circleId': 'cA', 'teacherId': 't1',
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('enrollments/e_s3', {
    'centerId': 'c1', 'studentId': 's3', 'circleId': 'cA', 'teacherId': 't2',
    'startDate': 1700000000000, 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

void main() {
  late FakeFirestoreDataSource store;
  late TeacherSessionService svc;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    svc = TeacherSessionService(store, clock: () => _today);
  });

  Future<void> start(String id, {String teacher = 't1', String center = 'c1'}) =>
      svc.start(centerId: center, teacherId: teacher, sessionId: id);
  Future<void> record(String session, String student, AttendanceStatus st,
          {String? note, String teacher = 't1'}) =>
      svc.record(centerId: 'c1', teacherId: teacher, sessionId: session,
          studentId: student, status: st, note: note);

  group('start / complete', () {
    test('a scheduled session starts today and is stamped', () async {
      await start('sched');
      final d = (await store.getDoc('schedules/sched'))!;
      expect(d['status'], 'inProgress');
      expect(d['startedAt'], isNotNull);
    });

    test('not on another day, not twice, not when finished', () async {
      await expectLater(start('tomorrow'), throwsA(isA<SessionException>()));
      await expectLater(start('live'), throwsA(isA<SessionException>()));
      await expectLater(start('done'), throwsA(isA<SessionException>()));
      expect((await store.getDoc('schedules/tomorrow'))!['status'], 'scheduled');
    });

    test('someone else\'s, other-center and missing sessions are "not found"', () async {
      for (final id in ['theirs', 'foreign', 'nope']) {
        await expectLater(start(id), throwsA(isA<SessionException>()), reason: id);
      }
      await expectLater(start('sched', teacher: 't2'), throwsA(isA<SessionException>()));
      await expectLater(start('sched', center: 'c2'), throwsA(isA<SessionException>()));
    });

    test('only an in-progress session completes', () async {
      await svc.complete(centerId: 'c1', teacherId: 't1', sessionId: 'live');
      final d = (await store.getDoc('schedules/live'))!;
      expect(d['status'], 'completed');
      expect(d['completedAt'], isNotNull);
      await expectLater(
          svc.complete(centerId: 'c1', teacherId: 't1', sessionId: 'sched'),
          throwsA(isA<SessionException>()));
      await expectLater(
          svc.complete(centerId: 'c1', teacherId: 't1', sessionId: 'done'),
          throwsA(isA<SessionException>()));
    });
  });

  group('roster', () {
    test('lists only this teacher\'s active students of the circle, by name', () async {
      final r = await svc.loadRoster(centerId: 'c1', teacherId: 't1', sessionId: 'live');
      expect(r.circleName, 'حلقة الفجر');
      expect(r.students.map((s) => s.studentId), ['s2', 's1']); // أحمد before بسمة
      expect(r.missing, hasLength(2));
    });

    test('shows existing records and what is still missing', () async {
      await record('live', 's1', AttendanceStatus.present);
      final r = await svc.loadRoster(centerId: 'c1', teacherId: 't1', sessionId: 'live');
      expect(r.records['s1']!.status, AttendanceStatus.present);
      expect(r.missing.map((s) => s.studentId), ['s2']);
    });
  });

  group('record', () {
    test('creates a record with the deterministic id, attributed to the teacher', () async {
      await record('live', 's1', AttendanceStatus.late, note: '  تأخر قليلًا ');
      final d = (await store.getDoc('attendance/live_s1'))!;
      expect(d['status'], 'late');
      expect(d['recordedBy'], 't1');
      expect(d['centerId'], 'c1');
      expect(d['note'], 'تأخر قليلًا');
    });

    test('recording again fixes the same record; there is never a duplicate', () async {
      await record('live', 's1', AttendanceStatus.absent);
      final created = (await store.getDoc('attendance/live_s1'))!['createdAt'];
      await record('live', 's1', AttendanceStatus.present, note: '');
      final all = await store.query('attendance', where: []);
      expect(all, hasLength(1));
      expect(all.single['status'], 'present');
      expect(all.single['note'], isNull);
      expect(all.single['createdAt'], created); // original creation time kept
    });

    test('refused before the session starts and after it ends', () async {
      await expectLater(record('sched', 's1', AttendanceStatus.present), throwsA(isA<SessionException>()));
      await expectLater(record('done', 's1', AttendanceStatus.present), throwsA(isA<SessionException>()));
      expect(await store.query('attendance', where: []), isEmpty);
    });

    test('refused for students not in this teacher\'s roster', () async {
      await expectLater(record('live', 's3', AttendanceStatus.present), throwsA(isA<SessionException>())); // other teacher's
      await expectLater(record('live', 's4', AttendanceStatus.present), throwsA(isA<SessionException>())); // no enrolment
      await expectLater(record('live', 'ghost', AttendanceStatus.present), throwsA(isA<SessionException>()));
      expect(await store.query('attendance', where: []), isEmpty);
    });

    test('refused on another teacher\'s session', () async {
      await expectLater(record('theirs', 's1', AttendanceStatus.present), throwsA(isA<SessionException>()));
    });
  });

  group('assessments', () {
    final at = DateTime(2026, 11, 10, 8, 30);

    Future<void> save(String session, String student,
            {String id = 'rec1', AssessmentDraft? draft, String teacher = 't1'}) =>
        svc.saveAssessment(
          centerId: 'c1',
          teacherId: teacher,
          sessionId: session,
          studentId: student,
          recordId: id,
          assessedAt: at,
          draft: draft ??
              const AssessmentDraft(
                type: AssessmentType.newMemorization,
                grade: WirdGrade.veryGood,
                surah: 2,
                startAyah: 1,
                endAyah: 5,
                scores: {'accuracy': 4},
                mistakesCount: 2,
                studentVisibleFeedback: '  أحسنت  ',
                privateNote: ' يحتاج متابعة ',
              ),
        );

    test('saves the assessment and keeps the private note in a separate document', () async {
      await save('live', 's1');
      final rec = (await store.getDoc('memorization_records/rec1'))!;
      expect(rec['surah'], 2);
      expect(rec['startAyah'], 1);
      expect(rec['endAyah'], 5);
      expect(rec['teacherId'], 't1');
      expect(rec['sessionId'], 'live');
      expect(rec['circleId'], 'cA');
      expect(rec['schemaVersion'], 1);
      expect(rec['studentVisibleFeedback'], 'أحسنت');
      expect((rec['criteriaScores'] as Map)['accuracy'], 4.0);
      // The student-readable document must not contain the private note anywhere.
      expect(rec.containsKey('privateTeacherNote'), isFalse);
      expect('$rec', isNot(contains('يحتاج متابعة')));

      final note = (await store.getDoc('private_teacher_notes/rec1'))!;
      expect(note['note'], 'يحتاج متابعة');
      expect(note['studentId'], 's1');
      expect(note['teacherId'], 't1');
    });

    test('no private note document is written when there is no private note', () async {
      await save('live', 's1',
          draft: const AssessmentDraft(
              type: AssessmentType.recentRevision, grade: WirdGrade.good, surah: 1, startAyah: 1, endAyah: 7, privateNote: '   '));
      expect(await store.query('private_teacher_notes', where: []), isEmpty);
      expect(await store.getDoc('memorization_records/rec1'), isNotNull);
    });

    test('retrying the same form rewrites the same record, never a second', () async {
      await save('live', 's1');
      await save('live', 's1');
      expect(await store.query('memorization_records', where: []), hasLength(1));
    });

    test('the roster counts this session\'s assessments per student', () async {
      await save('live', 's1', id: 'a');
      await save('live', 's1', id: 'b');
      await save('live', 's2', id: 'c');
      final r = await svc.loadRoster(centerId: 'c1', teacherId: 't1', sessionId: 'live');
      expect(r.assessmentCounts, {'s1': 2, 's2': 1});
    });

    test('invalid ranges are refused before anything is written', () async {
      for (final bad in [
        const AssessmentDraft(type: AssessmentType.newMemorization, grade: WirdGrade.good, surah: 1, startAyah: 1, endAyah: 8),
        const AssessmentDraft(type: AssessmentType.newMemorization, grade: WirdGrade.good, surah: 2, startAyah: 6, endAyah: 5),
        const AssessmentDraft(type: AssessmentType.newMemorization, grade: WirdGrade.good, surah: 200, startAyah: 1, endAyah: 1),
        const AssessmentDraft(type: AssessmentType.newMemorization, grade: WirdGrade.good, surah: 2, startAyah: 1, endAyah: 5, mistakesCount: -1),
        const AssessmentDraft(type: AssessmentType.newMemorization, grade: WirdGrade.good, surah: 2, startAyah: 1, endAyah: 5, scores: {'accuracy': 9}),
      ]) {
        await expectLater(save('live', 's1', draft: bad), throwsA(isA<SessionException>()));
      }
      expect(await store.query('memorization_records', where: []), isEmpty);
    });

    test('the grade is stored, and every graded wird needs one', () async {
      await save('live', 's1');
      expect((await store.getDoc('memorization_records/rec1'))!['grade'], 'veryGood');
      await expectLater(
        save('live', 's1',
            id: 'nograde',
            draft: const AssessmentDraft(
                type: AssessmentType.recentRevision, surah: 1, startAyah: 1, endAyah: 7)),
        throwsA(isA<SessionException>()),
      );
      expect(await store.getDoc('memorization_records/nograde'), isNull);
    });

    test('the new assignment is not graded, and any grade given to it is dropped', () async {
      await save('live', 's1',
          id: 'next',
          draft: const AssessmentDraft(
              type: AssessmentType.newAssignment, grade: WirdGrade.excellent, surah: 2, startAyah: 6, endAyah: 10));
      final r = (await store.getDoc('memorization_records/next'))!;
      expect(r['assessmentType'], 'newAssignment');
      expect(r.containsKey('grade'), isFalse);
    });

    test('a visit groups its wirds under one visit id', () async {
      for (final t in [AssessmentType.newMemorization, AssessmentType.recentRevision]) {
        await save('live', 's1',
            id: 'v1_${t.name}',
            draft: AssessmentDraft(
                type: t, grade: WirdGrade.good, visitId: 'v1', surah: 1, startAyah: 1, endAyah: 3));
      }
      final all = await store.query('memorization_records', where: []);
      expect(all.map((r) => r['visitId']).toSet(), {'v1'});
      expect(all, hasLength(2));
    });

    test('only for the teacher\'s own in-progress session and own students', () async {
      await expectLater(save('sched', 's1'), throwsA(isA<SessionException>()));
      await expectLater(save('done', 's1'), throwsA(isA<SessionException>()));
      await expectLater(save('theirs', 's1'), throwsA(isA<SessionException>()));
      await expectLater(save('live', 's3'), throwsA(isA<SessionException>()));
      await expectLater(save('live', 's4'), throwsA(isA<SessionException>()));
      expect(await store.query('memorization_records', where: []), isEmpty);
    });
  });

  group('visiting students', () {
    setUp(() async {
      await store.setDoc('student_directory/s3', {'centerId': 'c1', 'fullName': 'ليس طالبي', 'active': true});
      await store.setDoc('student_directory/s1', {'centerId': 'c1', 'fullName': 'بسمة', 'active': true});
      await store.setDoc('student_directory/s2', {'centerId': 'c1', 'fullName': 'أحمد', 'active': true});
      await store.setDoc('student_directory/gone', {'centerId': 'c1', 'fullName': 'مؤرشف', 'active': false});
      await store.setDoc('student_directory/other', {'centerId': 'c2', 'fullName': 'مركز آخر', 'active': true});
    });

    test('lists active students of the center who are not already in the circle', () async {
      final names = (await svc.findableStudents('c1', 't1', 'live')).map((g) => g.name);
      expect(names, ['ليس طالبي']); // s1/s2 are in the circle; archived and other-center are out
    });

    test('a guest can be added to a running session only, once, and must be a real active student', () async {
      await svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: 's3');
      await svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: 's3'); // idempotent
      expect(((await store.getDoc('schedules/live'))!['guestStudentIds'] as List), ['s3']);
      for (final bad in ['gone', 'other', 'ghost']) {
        await expectLater(
            svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: bad),
            throwsA(isA<SessionException>()),
            reason: bad);
      }
      await expectLater(
          svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'sched', studentId: 's3'),
          throwsA(isA<SessionException>()));
      await expectLater(
          svc.addGuest(centerId: 'c1', teacherId: 't2', sessionId: 'live', studentId: 's3'),
          throwsA(isA<SessionException>()));
    });

    test('once added, attendance and a graded wird can be recorded for the guest; before, not', () async {
      await expectLater(record('live', 's3', AttendanceStatus.present), throwsA(isA<SessionException>()));
      await svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: 's3');
      await record('live', 's3', AttendanceStatus.present);
      await svc.saveAssessment(
        centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: 's3', recordId: 'g1',
        assessedAt: DateTime(2026, 11, 10),
        draft: const AssessmentDraft(
            type: AssessmentType.newMemorization, grade: WirdGrade.excellent, surah: 1, startAyah: 1, endAyah: 7),
      );
      expect((await store.getDoc('memorization_records/g1'))!['studentId'], 's3');
      expect((await store.getDoc('attendance/live_s3'))!['recordedBy'], 't1');
    });

    test('the roster lists guests by name only', () async {
      await svc.addGuest(centerId: 'c1', teacherId: 't1', sessionId: 'live', studentId: 's3');
      final r = await svc.loadRoster(centerId: 'c1', teacherId: 't1', sessionId: 'live');
      expect(r.guests.map((g) => g.name), ['ليس طالبي']);
      expect(r.students.map((s) => s.studentId), isNot(contains('s3')));
    });
  });
}
