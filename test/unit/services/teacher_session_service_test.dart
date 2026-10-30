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
}
