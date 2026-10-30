import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/design_system/components/kpi_card.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

import '../../support/app_harness.dart';

const _accounts = {
  'dir@x.com': ('pw', 'dir-1'),
  'new@x.com': ('pw', 'dir-new'),
};

/// Fails the next [failures] writes, like a dropped connection.
class _FlakyStore extends FakeFirestoreDataSource {
  int failures = 0;

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data,
      {bool merge = false}) async {
    if (failures > 0) {
      failures--;
      throw StateError('network down');
    }
    return super.setDoc(path, data, merge: merge);
  }
}

int _ms(DateTime d) => d.millisecondsSinceEpoch;

Future<void> _seed(FakeFirestoreDataSource s) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await seedUser(s, 'dir-1', 'director', name: 'مديرة الدار');
  // A different center with nothing in it.
  await seedUser(s, 'dir-new', 'director', centerId: 'center-9', name: 'مديرة جديدة');

  Future<void> student(String id, String center, String status) =>
      s.setDoc('students/$id', {
        'centerId': center,
        'fullName': 'طالب $id',
        'accountMode': 'none',
        'enrollmentStatus': status,
        'assignedTeacherIds': [],
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await student('a', 'center-1', 'active');
  await student('b', 'center-1', 'active');
  await student('c', 'center-1', 'archived');
  await student('x', 'center-2', 'active'); // other center: must not count

  Future<void> teacher(String id, String center, String status) =>
      s.setDoc('teachers/$id', {
        'centerId': center,
        'fullName': 'المعلم $id',
        'status': status,
        'assignedCircleIds': [],
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await teacher('t1', 'center-1', 'active');
  await teacher('t2', 'center-1', 'suspended');
  await teacher('t3', 'center-2', 'active');

  Future<void> circle(String id, String center, String name, String status,
          {String? teacher}) =>
      s.setDoc('circles/$id', {
        'centerId': center,
        'name': name,
        'educationalLevel': 'مبتدئ',
        'assignedTeacherId': teacher,
        'maxCapacity': 20,
        'locationOrMode': 'onsite',
        'weeklySchedule': [],
        'sessionDurationMinutes': 60,
        'status': status,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await circle('c1', 'center-1', 'حلقة الفجر', 'active', teacher: 't1');
  await circle('c2', 'center-1', 'حلقة المغرب', 'archived');
  await circle('c3', 'center-2', 'حلقة أخرى', 'active');

  Future<void> session(String id, String center, DateTime d, String status) =>
      s.setDoc('schedules/$id', {
        'centerId': center,
        'circleId': 'c1',
        'teacherId': 't1',
        'date': _ms(d),
        'startTime': '08:00',
        'endTime': '09:00',
        'locationOrMode': 'onsite',
        'status': status,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await session('s1', 'center-1', today, 'scheduled');
  await session('s2', 'center-1', today, 'completed');
  await session('s3', 'center-1', today.add(const Duration(days: 1)), 'scheduled');

  Future<void> att(String id, String status, Duration ago) =>
      s.setDoc('attendance/sess_$id', {
        'centerId': 'center-1',
        'sessionId': 'sess',
        'studentId': id,
        'status': status,
        'recordedBy': 't1',
        'createdAt': _ms(now.subtract(ago)),
        'updatedAt': _ms(now.subtract(ago)),
      });
  await att('a', 'present', const Duration(days: 1));
  await att('b', 'absent', const Duration(days: 2));
  await att('old', 'absent', const Duration(days: 20)); // outside the 7-day window
}

String _kpi(WidgetTester tester, String label) => tester
    .widget<KpiCard>(find.byWidgetPredicate((w) => w is KpiCard && w.label == label))
    .value;

Finder _navItem(String label) => find.descendant(
    of: find.byType(DirectorBottomNav), matching: find.text(label));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('dashboard', () {
    testWidgets('shows this center\'s real numbers, not placeholders', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');

      expect(_kpi(tester, 'طلاب منتظمون'), '2'); // a, b (c archived, x other center)
      expect(_kpi(tester, 'معلمون نشطون'), '1'); // t1 only
      expect(_kpi(tester, 'حلقات نشطة'), '1'); // c1 only
      expect(_kpi(tester, 'جلسات اليوم'), '2'); // s1 + s2 (s3 is tomorrow)
      // present 1 / (present 1 + absent 1) within the last 7 days; the 20-day-old absence is ignored.
      expect(find.text('نسبة الحضور: 50.0%'), findsOneWidget);
    });

    testWidgets('a brand-new center gets zeros and a getting-started hint', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('new@x.com', 'pw');

      expect(_kpi(tester, 'طلاب منتظمون'), '0');
      expect(_kpi(tester, 'معلمون نشطون'), '0');
      expect(find.textContaining('لم تُضف بيانات بعد'), findsOneWidget);
      expect(find.text('لا توجد سجلات حضور خلال آخر 7 أيام.'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('bottom bar moves between sections', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');

      await tester.tap(_navItem('الطلاب'));
      await tester.pumpAndSettle();
      expect(find.text('إدارة الطلاب'), findsOneWidget);

      await tester.tap(_navItem('المعلمون'));
      await tester.pumpAndSettle();
      expect(find.text('إدارة المعلمين'), findsOneWidget);

      await tester.tap(_navItem('الحلقات'));
      await tester.pumpAndSettle();
      expect(find.text('إدارة الحلقات'), findsOneWidget);

      await tester.tap(_navItem('نظرة عامة'));
      await tester.pumpAndSettle();
      expect(find.text('أهلاً بك، مديرة الدار'), findsOneWidget);
    });

    testWidgets('More reaches schedules and attendance and offers sign-out', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');

      await tester.tap(_navItem('المزيد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إدارة الجدول'));
      await tester.pumpAndSettle();
      expect(find.text('إنشاء جلسة'), findsOneWidget);

      app.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('إدارة الحضور'));
      await tester.pumpAndSettle();
      // All three records (the 20-day-old absence included): 1 present / 3.
      expect(find.text('نسبة الحضور: 33.3%'), findsOneWidget);
      expect(find.textContaining('تشمل جميع السجلات'), findsOneWidget);

      app.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('quick actions open real screens', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');

      await tester.tap(find.widgetWithText(ActionChip, 'إضافة طالب'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة طالب جديد'), findsOneWidget);
    });
  });

  group('create circle', () {
    Future<AppHarness> open(WidgetTester tester, {FakeFirestoreDataSource? store}) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed, store: store);
      await app.signIn('dir@x.com', 'pw');
      await app.go('/director/circles/add');
      return app;
    }

    testWidgets('invalid input is explained and nothing is saved', (tester) async {
      final app = await open(tester);
      await tester.enterText(find.widgetWithText(TextField, 'السعة القصوى *'), '0');
      await tester.tap(find.text('حفظ الحلقة'));
      await tester.pumpAndSettle();

      expect(find.text('اسم الحلقة مطلوب'), findsOneWidget);
      expect(find.text('السعة بين 1 و 500'), findsOneWidget);
      final circles = await app.store.query('circles', where: []);
      expect(circles, hasLength(3)); // only the seeded ones
    });

    testWidgets('saves a scoped, attributed circle with its schedule and teacher',
        (tester) async {
      final app = await open(tester);
      await tester.enterText(find.widgetWithText(TextField, 'اسم الحلقة *'), '  حلقة الظهر  ');
      await tester.enterText(find.widgetWithText(TextField, 'السعة القصوى *'), '25');

      await tester.tap(find.text('السبت'));
      await tester.tap(find.text('الاثنين'));
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      // Only the active teacher of this center is offered.
      expect(find.text('المعلم t2'), findsNothing); // suspended
      expect(find.text('المعلم t3'), findsNothing); // other center
      await tester.tap(find.text('المعلم t1').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ الحلقة'));
      await tester.pumpAndSettle();

      final saved = (await app.store.query('circles', where: []))
          .singleWhere((c) => c['name'] == 'حلقة الظهر');
      expect(saved['centerId'], 'center-1');
      expect(saved['maxCapacity'], 25);
      expect(saved['assignedTeacherId'], 't1');
      expect(saved['status'], 'active');
      expect(saved['createdBy'], 'dir-1');
      expect((saved['weeklySchedule'] as List).map((e) => e['dayOfWeek']).toSet(), {6, 1});

      // Lands on the list, which now shows the new circle with its teacher.
      expect(find.text('إدارة الحلقات'), findsOneWidget);
      expect(find.text('حلقة الظهر'), findsOneWidget);
    });

    testWidgets('a failed save keeps the form and a retry never duplicates', (tester) async {
      final store = _FlakyStore();
      final app = await open(tester, store: store);
      await tester.enterText(find.widgetWithText(TextField, 'اسم الحلقة *'), 'حلقة العصر');

      store.failures = 1;
      await tester.tap(find.text('حفظ الحلقة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذر حفظ الحلقة'), findsOneWidget);
      expect(find.text('حلقة العصر'), findsOneWidget); // typed text kept
      expect((await app.store.query('circles', where: [])).where((c) => c['name'] == 'حلقة العصر'),
          isEmpty);

      await tester.tap(find.text('حفظ الحلقة'));
      await tester.pumpAndSettle();
      expect((await app.store.query('circles', where: [])).where((c) => c['name'] == 'حلقة العصر'),
          hasLength(1));
    });
  });

  group('circle list', () {
    testWidgets('shows own center only, with teacher and search', (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');
      await app.go('/director/circles');

      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsOneWidget);
      expect(find.text('حلقة أخرى'), findsNothing); // other center
      expect(find.text('المعلم t1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'الفجر');
      await tester.pumpAndSettle();
      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);

      await tester.enterText(find.byType(TextField), 'لا يوجد');
      await tester.pumpAndSettle();
      expect(find.text('لا توجد حلقات مطابقة'), findsOneWidget);
    });

    testWidgets('archiving asks first; cancel changes nothing, confirm archives',
        (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: _seed);
      await app.signIn('dir@x.com', 'pw');
      await app.go('/director/circles');

      Future<void> openArchive() async {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('أرشفة').last);
        await tester.pumpAndSettle();
      }

      await openArchive();
      expect(find.textContaining('يبقى سجل الطلاب'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('circles/c1'))!['status'], 'active');

      await openArchive();
      await tester.tap(find.widgetWithText(FilledButton, 'أرشفة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('circles/c1'))!['status'], 'archived');
      expect(find.text('تمت أرشفة الحلقة'), findsOneWidget);
    });
  });
}
