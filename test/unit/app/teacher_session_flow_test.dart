import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {
  'tea@x.com': ('pw', 'tea-1'),
  'new@x.com': ('pw', 'tea-new'),
};

int _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset).millisecondsSinceEpoch;
}

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  await seedUser(s, 'tea-new', 'teacher', name: 'معلمة جديدة');

  Future<void> circle(String id, String name, String teacher) =>
      s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': name, 'educationalLevel': 'x', 'maxCapacity': 10,
        'assignedTeacherId': teacher, 'locationOrMode': 'onsite', 'weeklySchedule': [],
        'sessionDurationMinutes': 60, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 'tea-1');
  await circle('cB', 'حلقة المغرب', 'tea-2');

  Future<void> session(String id, String circleId, String teacher, int day, String status,
          {String start = '08:00'}) =>
      s.setDoc('schedules/$id', {
        'centerId': 'center-1', 'circleId': circleId, 'teacherId': teacher, 'date': _day(day),
        'startTime': start, 'endTime': '09:00', 'locationOrMode': 'onsite', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('today', 'cA', 'tea-1', 0, 'scheduled');
  await session('todayDone', 'cA', 'tea-1', 0, 'completed', start: '06:00');
  await session('tomorrow', 'cA', 'tea-1', 1, 'scheduled');
  await session('others', 'cB', 'tea-2', 0, 'scheduled');

  for (final (id, name) in [('s1', 'بسمة خالد'), ('s2', 'أحمد علي')]) {
    await s.setDoc('students/$id', {
      'centerId': 'center-1', 'fullName': name, 'accountMode': 'none',
      'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-1'],
      'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'center-1', 'studentId': id, 'circleId': 'cA', 'teacherId': 'tea-1',
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('students/s9', {
    'centerId': 'center-1', 'fullName': 'طالب معلم آخر', 'accountMode': 'none',
    'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-2'],
    'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

Finder _chip(String student, String label) => find.descendant(
    of: find.ancestor(of: find.text(student), matching: find.byType(Card)),
    matching: find.widgetWithText(ChoiceChip, label));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, {String as = 'tea@x.com', String? path}) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn(as, 'pw');
    if (path != null) await app.go(path);
    return app;
  }

  group('home', () {
    testWidgets('shows this teacher\'s counts and today\'s sessions only', (tester) async {
      await open(tester);
      expect(find.text('أهلاً بك، المعلمة فاطمة'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // my students (s9 belongs to another teacher)
      expect(find.text('1'), findsWidgets); // my circles
      expect(find.text('لم تبدأ'), findsOneWidget);
      expect(find.text('منتهية'), findsOneWidget);
      // The other teacher's session is not shown: only cA's two sessions are.
      expect(find.text('حلقة الفجر'), findsNWidgets(3)); // 2 today + 1 upcoming
      expect(find.text('حلقة المغرب'), findsNothing);
    });

    testWidgets('a teacher with no assignments sees a clear message, not zeros', (tester) async {
      await open(tester, as: 'new@x.com');
      expect(find.textContaining('لم تُسند إليك حلقات أو طلاب بعد'), findsOneWidget);
    });
  });

  group('session', () {
    Future<AppHarness> openToday(WidgetTester tester) async {
      final app = await open(tester, path: '/teacher/sessions/today');
      return app;
    }

    testWidgets('cannot mark attendance before the session starts', (tester) async {
      final app = await openToday(tester);
      expect(find.text('بدء الجلسة'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(_chip('بسمة خالد', 'حاضر'));
      expect(chip.onSelected, isNull);
      expect(await app.store.query('attendance', where: []), isEmpty);
    });

    testWidgets('start, record, fix, then complete with the missing count confirmed',
        (tester) async {
      final app = await openToday(tester);
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('schedules/today'))!['status'], 'inProgress');

      // Roster is by name: أحمد before بسمة.
      expect(tester.getTopLeft(find.text('أحمد علي')).dy,
          lessThan(tester.getTopLeft(find.text('بسمة خالد')).dy));

      await tester.tap(_chip('بسمة خالد', 'غائب'));
      await tester.pumpAndSettle();
      var rec = (await app.store.getDoc('attendance/today_s1'))!;
      expect(rec['status'], 'absent');
      expect(rec['recordedBy'], 'tea-1');

      // Fixing a mistake while in progress rewrites the same record.
      await tester.tap(_chip('بسمة خالد', 'حاضر'));
      await tester.pumpAndSettle();
      rec = (await app.store.getDoc('attendance/today_s1'))!;
      expect(rec['status'], 'present');
      expect(await app.store.query('attendance', where: []), hasLength(1));
      expect(find.textContaining('سُجِّل 1'), findsOneWidget);

      await tester.dragUntilVisible(
          find.text('إنهاء الجلسة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('إنهاء الجلسة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لم يُسجَّل حضور 1 طالبًا'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'إنهاء الجلسة').last);
      await tester.pumpAndSettle();

      expect((await app.store.getDoc('schedules/today'))!['status'], 'completed');
      expect(find.textContaining('تعديل الحضور بعد انتهائها يتم عبر الإدارة'), findsOneWidget);
      // Read-only now.
      expect(tester.widget<ChoiceChip>(_chip('بسمة خالد', 'غائب')).onSelected, isNull);
    });

    testWidgets('cancelling the finish dialog leaves the session running', (tester) async {
      final app = await openToday(tester);
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.text('إنهاء الجلسة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('إنهاء الجلسة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('schedules/today'))!['status'], 'inProgress');
    });

    testWidgets('a session of a future day cannot be started', (tester) async {
      final app = await open(tester, path: '/teacher/sessions/tomorrow');
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      expect(find.text('يمكن بدء الجلسة في يومها فقط.'), findsOneWidget);
      expect((await app.store.getDoc('schedules/tomorrow'))!['status'], 'scheduled');
    });

    testWidgets('another teacher\'s session is simply not found', (tester) async {
      await open(tester, path: '/teacher/sessions/others');
      expect(find.text('لم يتم العثور على الجلسة.'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);
    });

    testWidgets('a failed save is reported and can be retried', (tester) async {
      final store = _FlakyStore();
      final app = await bootApp(tester, accounts: _accounts, seed: _seed, store: store);
      await app.signIn('tea@x.com', 'pw');
      await app.go('/teacher/sessions/today');
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();

      store.failNextWrite = true;
      await tester.tap(_chip('بسمة خالد', 'حاضر'));
      await tester.pumpAndSettle();
      expect(find.text('تعذر حفظ الحضور. حاول مرة أخرى.'), findsOneWidget);
      expect(await store.getDoc('attendance/today_s1'), isNull);

      await tester.tap(_chip('بسمة خالد', 'حاضر'));
      await tester.pumpAndSettle();
      expect((await store.getDoc('attendance/today_s1'))!['status'], 'present');
    });
  });

  group('circles', () {
    testWidgets('lists only my circles with my student counts', (tester) async {
      await open(tester, path: '/teacher/circles');
      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);
      expect(find.textContaining('2 طالب'), findsOneWidget);
    });
  });
}

class _FlakyStore extends FakeFirestoreDataSource {
  bool failNextWrite = false;

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data, {bool merge = false}) async {
    if (failNextWrite && path.startsWith('attendance/')) {
      failNextWrite = false;
      throw StateError('network down');
    }
    return super.setDoc(path, data, merge: merge);
  }
}
