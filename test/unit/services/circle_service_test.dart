import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/services/circle_service.dart';

final _today = DateTime(2026, 11, 10, 9);
int _ms(DateTime d) => d.millisecondsSinceEpoch;

Future<void> _seed(FakeFirestoreDataSource s) async {
  Future<void> circle(String id, {String status = 'active', String center = 'c1', String? teacher, int cap = 5}) =>
      s.setDoc('circles/$id', {
        'centerId': center, 'name': 'حلقة $id', 'educationalLevel': 'مبتدئ',
        'assignedTeacherId': teacher, 'maxCapacity': cap, 'locationOrMode': 'onsite',
        'weeklySchedule': [], 'sessionDurationMinutes': 60, 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('A', teacher: 'tOld');
  await circle('empty');
  await circle('gone', status: 'archived');
  await circle('foreign', center: 'c2');

  Future<void> teacher(String id, {String status = 'active', String center = 'c1'}) =>
      s.setDoc('teachers/$id', {
        'centerId': center, 'userId': id, 'fullName': 'م $id', 'status': status,
        'assignedCircleIds': [], 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await teacher('tOld');
  await teacher('tNew');
  await teacher('tSusp', status: 'suspended');
  await teacher('tOther', center: 'c2');

  for (final id in ['s1', 's2']) {
    await s.setDoc('students/$id', {
      'centerId': 'c1', 'fullName': id, 'accountMode': 'none', 'enrollmentStatus': 'active',
      'assignedTeacherIds': ['tOld'], 'educationalLevel': 'x',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'c1', 'studentId': id, 'circleId': 'A', 'teacherId': 'tOld',
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  // A closed enrolment of a former student: must not be touched.
  await s.setDoc('students/s9', {
    'centerId': 'c1', 'fullName': 's9', 'accountMode': 'none', 'enrollmentStatus': 'active',
    'assignedTeacherIds': ['tOld'], 'educationalLevel': 'x',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  await s.setDoc('enrollments/e_old', {
    'centerId': 'c1', 'studentId': 's9', 'circleId': 'A', 'teacherId': 'tOld',
    'startDate': 1700000000000, 'status': 'transferred',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });

  Future<void> session(String id, DateTime d, String status) => s.setDoc('schedules/$id', {
        'centerId': 'c1', 'circleId': 'A', 'teacherId': 'tOld', 'date': _ms(d),
        'startTime': '08:00', 'endTime': '09:00', 'locationOrMode': 'onsite',
        'status': status, 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('future', DateTime(2026, 11, 12), 'scheduled');
  await session('todayS', DateTime(2026, 11, 10), 'scheduled');
  await session('past', DateTime(2026, 11, 1), 'scheduled');
  await session('done', DateTime(2026, 11, 20), 'completed');
}

class _FailingBatch extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async => throw StateError('down');
}

void main() {
  late FakeFirestoreDataSource store;
  late CircleService svc;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    svc = CircleService(store, clock: () => _today);
  });

  Future<bool> edit(String id, {String name = 'حلقة A', int cap = 5, String? teacher = 'tOld',
          String level = 'مبتدئ', String mode = 'onsite', String? description, String center = 'c1',
          List<CircleWeeklySchedule>? schedule}) =>
      svc.update(id,
          centerId: center, actorId: 'dir-1', actorRole: 'director', name: name,
          educationalLevel: level, description: description, maxCapacity: cap,
          sessionDurationMinutes: 60, locationOrMode: mode, teacherId: teacher,
          weeklySchedule: schedule);

  Future<String?> teacherOf(String path, [String field = 'teacherId']) async =>
      (await store.getDoc(path))![field] as String?;

  test('changing only descriptive fields leaves teachers, students and sessions alone', () async {
    expect(await edit('A', name: 'حلقة النور', cap: 8), isTrue);
    final c = (await store.getDoc('circles/A'))!;
    expect(c['name'], 'حلقة النور');
    expect(c['maxCapacity'], 8);
    expect(c['updatedBy'], 'dir-1');
    expect(await teacherOf('enrollments/e_s1'), 'tOld');
    expect((await store.getDoc('students/s1'))!['assignedTeacherIds'], ['tOld']);
    final audit = (await store.query('audit_logs', where: [])).single;
    expect(audit['action'], 'update_circle');
    expect((audit['newValue'] as Map).keys.toSet(), {'name', 'maxCapacity'});
  });

  test('the weekly schedule can be replaced, per day, and is audited', () async {
    expect(
        await edit('A', schedule: const [
          CircleWeeklySchedule(dayOfWeek: 6, startTime: '08:00', endTime: '09:30'),
          CircleWeeklySchedule(dayOfWeek: 1, startTime: '16:00', endTime: '17:00'),
        ]),
        isTrue);
    final c = (await store.getDoc('circles/A'))!;
    expect((c['weeklySchedule'] as List).map((w) => '${w['dayOfWeek']} ${w['startTime']}-${w['endTime']}').toList(),
        ['1 16:00-17:00', '6 08:00-09:30']);
    final audit = (await store.query('audit_logs', where: [])).single;
    expect(audit['action'], 'update_circle');
    expect((audit['newValue'] as Map).keys, ['weeklySchedule']);
  });

  test('re-saving the same schedule (any order) changes nothing; null leaves it alone', () async {
    await edit('A', schedule: const [CircleWeeklySchedule(dayOfWeek: 6, startTime: '08:00', endTime: '09:00')]);
    expect(await edit('A', schedule: const [CircleWeeklySchedule(dayOfWeek: 6, startTime: '08:00', endTime: '09:00')]), isFalse);
    expect(await edit('A'), isFalse); // schedule null = untouched
  });

  test('an invalid or duplicated schedule is refused', () async {
    await expectLater(edit('A', schedule: const [CircleWeeklySchedule(dayOfWeek: 6, startTime: '09:00', endTime: '08:00')]), throwsA(isA<CircleException>()));
    await expectLater(edit('A', schedule: const [CircleWeeklySchedule(dayOfWeek: 9, startTime: '08:00', endTime: '09:00')]), throwsA(isA<CircleException>()));
    await expectLater(edit('A', schedule: const [
      CircleWeeklySchedule(dayOfWeek: 6, startTime: '08:00', endTime: '09:00'),
      CircleWeeklySchedule(dayOfWeek: 6, startTime: '10:00', endTime: '11:00'),
    ]), throwsA(isA<CircleException>()));
  });

  test('no change writes nothing and no audit', () async {
    expect(await edit('A'), isFalse);
    expect(await store.query('audit_logs', where: []), isEmpty);
  });

  test('a teacher change moves enrolments, students and upcoming sessions together', () async {
    expect(await edit('A', teacher: 'tNew'), isTrue);

    expect((await store.getDoc('circles/A'))!['assignedTeacherId'], 'tNew');
    for (final s in ['s1', 's2']) {
      expect(await teacherOf('enrollments/e_$s'), 'tNew');
      expect((await store.getDoc('students/$s'))!['assignedTeacherIds'], ['tNew']);
    }
    // Upcoming and today's scheduled sessions follow the new teacher...
    expect(await teacherOf('schedules/future'), 'tNew');
    expect(await teacherOf('schedules/todayS'), 'tNew');
    // ...history does not: past and completed sessions, closed enrolments, former students.
    expect(await teacherOf('schedules/past'), 'tOld');
    expect(await teacherOf('schedules/done'), 'tOld');
    expect(await teacherOf('enrollments/e_old'), 'tOld');
    expect((await store.getDoc('students/s9'))!['assignedTeacherIds'], ['tOld']);

    final audit = (await store.query('audit_logs', where: [])).single;
    expect(audit['action'], 'change_circle_teacher');
    expect((audit['previousValue'] as Map)['assignedTeacherId'], 'tOld');
    expect((audit['newValue'] as Map)['assignedTeacherId'], 'tNew');
  });

  test('removing the teacher clears the students\' assigned teacher', () async {
    await edit('A', teacher: null);
    expect((await store.getDoc('students/s1'))!['assignedTeacherIds'], isEmpty);
    expect(await teacherOf('enrollments/e_s1'), isNull);
  });

  test('only active teachers of this center can be assigned', () async {
    for (final t in ['tSusp', 'tOther', 'ghost']) {
      await expectLater(edit('A', teacher: t), throwsA(isA<CircleException>()), reason: t);
    }
    expect((await store.getDoc('circles/A'))!['assignedTeacherId'], 'tOld');
    expect(await store.query('audit_logs', where: []), isEmpty);
  });

  test('capacity cannot drop below the current students', () async {
    await expectLater(edit('A', cap: 1), throwsA(isA<CircleException>()));
    expect(await edit('A', cap: 2), isTrue); // exactly the current count is fine
  });

  test('invalid values, archived, other-center and missing circles are refused', () async {
    await expectLater(edit('A', name: '  '), throwsA(isA<CircleException>()));
    await expectLater(edit('A', cap: 0), throwsA(isA<CircleException>()));
    await expectLater(edit('gone'), throwsA(isA<CircleException>()));
    await expectLater(edit('foreign'), throwsA(isA<CircleException>()));
    await expectLater(edit('nope'), throwsA(isA<CircleException>()));
    await expectLater(edit('A', center: 'c2'), throwsA(isA<CircleException>()));
    expect(await store.query('audit_logs', where: []), isEmpty);
  });

  test('a failed atomic write leaves everything as it was', () async {
    final broken = _FailingBatch();
    await _seed(broken);
    final s = CircleService(broken, clock: () => _today);
    await expectLater(
      s.update('A', centerId: 'c1', actorId: 'd', actorRole: 'director', name: 'x',
          educationalLevel: 'y', maxCapacity: 5, sessionDurationMinutes: 60,
          locationOrMode: 'onsite', teacherId: 'tNew'),
      throwsStateError,
    );
    expect((await broken.getDoc('circles/A'))!['assignedTeacherId'], 'tOld');
    expect((await broken.getDoc('students/s1'))!['assignedTeacherIds'], ['tOld']);
  });

  Future<void> addBigRoster() async {
    for (var i = 0; i < 230; i++) {
      await store.setDoc('students/bs$i', {
        'centerId': 'c1', 'fullName': 'b$i', 'accountMode': 'none', 'enrollmentStatus': 'active',
        'assignedTeacherIds': ['tOld'], 'educationalLevel': 'x',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
      await store.setDoc('enrollments/big$i', {
        'centerId': 'c1', 'studentId': 'bs$i', 'circleId': 'A', 'teacherId': 'tOld',
        'startDate': 1700000000000, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
    }
  }

  test('a very large circle changes teacher in several batches, circle last', () async {
    await addBigRoster();
    expect(await edit('A', teacher: 'tNew', cap: 500), isTrue);
    expect((await store.getDoc('circles/A'))!['assignedTeacherId'], 'tNew');
    expect((await store.getDoc('students/bs229'))!['assignedTeacherIds'], ['tNew']);
    expect(await teacherOf('enrollments/big0'), 'tNew');
  });

  test('if a later batch fails the circle keeps its old teacher and the retry completes', () async {
    await addBigRoster();
    final flaky = _FailOnNth(2);
    for (final d in await store.query('students', where: [])) {
      await flaky.setDoc('students/${d['id']}', Map.of(d)..remove('id'));
    }
    for (final collection in ['circles', 'teachers', 'enrollments', 'schedules']) {
      for (final d in await store.query(collection, where: [])) {
        await flaky.setDoc('$collection/${d['id']}', Map.of(d)..remove('id'));
      }
    }
    final svc2 = CircleService(flaky, clock: () => _today);
    Future<bool> go() => svc2.update('A',
        centerId: 'c1', actorId: 'dir-1', actorRole: 'director', name: 'حلقة A',
        educationalLevel: 'مبتدئ', maxCapacity: 500, sessionDurationMinutes: 60,
        locationOrMode: 'onsite', teacherId: 'tNew');

    await expectLater(go(), throwsStateError);
    expect((await flaky.getDoc('circles/A'))!['assignedTeacherId'], 'tOld'); // not switched
    expect(await flaky.query('audit_logs', where: []), isEmpty);

    expect(await go(), isTrue); // repeating the same save finishes the job
    expect((await flaky.getDoc('circles/A'))!['assignedTeacherId'], 'tNew');
    expect((await flaky.getDoc('students/bs0'))!['assignedTeacherIds'], ['tNew']);
    expect((await flaky.getDoc('students/bs229'))!['assignedTeacherIds'], ['tNew']);
  });

  group('archive', () {
    test('refused while students are enrolled', () async {
      await expectLater(
        svc.archive('A', centerId: 'c1', actorId: 'd', actorRole: 'director'),
        throwsA(isA<CircleException>().having((e) => e.message, 'm', contains('2'))),
      );
      expect((await store.getDoc('circles/A'))!['status'], 'active');
    });

    test('an empty circle is archived with an audit entry', () async {
      await svc.archive('empty', centerId: 'c1', actorId: 'dir-1', actorRole: 'director');
      expect((await store.getDoc('circles/empty'))!['status'], 'archived');
      final audit = (await store.query('audit_logs', where: [])).single;
      expect(audit['action'], 'archive_circle');
      expect(audit['actorUserId'], 'dir-1');
    });

    test('already archived, foreign and missing circles are refused', () async {
      for (final id in ['gone', 'foreign', 'nope']) {
        await expectLater(
          svc.archive(id, centerId: 'c1', actorId: 'd', actorRole: 'director'),
          throwsA(isA<CircleException>()),
          reason: id,
        );
      }
    });
  });
}

/// Fails exactly the Nth batch commit, then behaves normally.
class _FailOnNth extends FakeFirestoreDataSource {
  _FailOnNth(this.n);
  final int n;
  int _calls = 0;

  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    _calls++;
    if (_calls == n) throw StateError('network down');
    return super.commitBatch(ops);
  }
}
