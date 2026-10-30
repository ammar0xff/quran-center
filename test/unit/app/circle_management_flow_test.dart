import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  Future<void> circle(String id, String name, String center,
          {String? teacher, int cap = 5, String status = 'active'}) =>
      s.setDoc('circles/$id', {
        'centerId': center, 'name': name, 'educationalLevel': 'مبتدئ',
        'assignedTeacherId': teacher, 'maxCapacity': cap, 'locationOrMode': 'onsite',
        'weeklySchedule': [
          {'dayOfWeek': 6, 'startTime': '08:00', 'endTime': '09:00'}
        ],
        'sessionDurationMinutes': 60, 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 'center-1', teacher: 't1');
  await circle('cEmpty', 'حلقة فارغة', 'center-1');
  await circle('cX', 'حلقة مركز آخر', 'center-2');

  Future<void> teacher(String id, String name, {String status = 'active'}) =>
      s.setDoc('teachers/$id', {
        'centerId': 'center-1', 'userId': id, 'fullName': name, 'status': status,
        'assignedCircleIds': [], 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await teacher('t1', 'المعلمة فاطمة');
  await teacher('t2', 'المعلمة خديجة');
  await teacher('t3', 'معلمة معلّقة', status: 'suspended');

  for (final (id, name) in [('s1', 'أحمد علي'), ('s2', 'بسمة خالد')]) {
    await s.setDoc('students/$id', {
      'centerId': 'center-1', 'fullName': name, 'accountMode': 'none',
      'enrollmentStatus': 'active', 'assignedTeacherIds': ['t1'],
      'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'center-1', 'studentId': id, 'circleId': 'cA', 'teacherId': 't1',
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('schedules/up1', {
    'centerId': 'center-1', 'circleId': 'cA', 'teacherId': 't1',
    'date': DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch,
    'startTime': '08:00', 'endTime': '09:00', 'locationOrMode': 'onsite',
    'status': 'scheduled', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, String path) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go(path);
    return app;
  }

  group('detail', () {
    testWidgets('shows the circle, its teacher, schedule and current students', (tester) async {
      await open(tester, '/director/circles/cA');
      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('المعلمة فاطمة'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.textContaining('السبت 08:00–09:00'), findsOneWidget);
      expect(find.text('أحمد علي'), findsOneWidget);
      expect(find.text('بسمة خالد'), findsOneWidget);
    });

    testWidgets('an empty circle says so; another center\'s circle is not found', (tester) async {
      final app = await open(tester, '/director/circles/cEmpty');
      expect(find.text('لا يوجد طلاب في هذه الحلقة بعد.'), findsOneWidget);
      await app.go('/director/circles/cX');
      expect(find.text('الحلقة غير موجودة'), findsOneWidget);
      expect(find.text('حلقة مركز آخر'), findsNothing);
    });

    testWidgets('tapping a student opens their profile', (tester) async {
      await open(tester, '/director/circles/cA');
      await tester.tap(find.text('أحمد علي'));
      await tester.pumpAndSettle();
      expect(find.text('ملف الطالب'), findsOneWidget);
    });

    testWidgets('Add student opens assignment with this circle preselected', (tester) async {
      await open(tester, '/director/circles/cEmpty');
      await tester.tap(find.text('إضافة طالب'));
      await tester.pumpAndSettle();
      expect(find.text('تعيين الطالب للحلقة'), findsOneWidget);
      expect(find.textContaining('حلقة فارغة'), findsWidgets);
    });

    testWidgets('archiving a circle that still has students is refused', (tester) async {
      final app = await open(tester, '/director/circles/cA');
      await tester.dragUntilVisible(find.text('أرشفة الحلقة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('أرشفة الحلقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'أرشفة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('في الحلقة 2 طالبًا'), findsOneWidget);
      expect((await app.store.getDoc('circles/cA'))!['status'], 'active');
    });

    testWidgets('an empty circle can be archived', (tester) async {
      final app = await open(tester, '/director/circles/cEmpty');
      await tester.dragUntilVisible(find.text('أرشفة الحلقة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('أرشفة الحلقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'أرشفة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('circles/cEmpty'))!['status'], 'archived');
      expect(find.text('تمت أرشفة الحلقة'), findsOneWidget);
    });
  });

  group('edit', () {
    testWidgets('changing the teacher warns, then moves students and sessions', (tester) async {
      final app = await open(tester, '/director/circles/cA/edit');
      expect(find.textContaining('يُنقل طلاب الحلقة'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('معلمة معلّقة'), findsNothing); // suspended: not offered
      await tester.tap(find.text('المعلمة خديجة').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('يُنقل طلاب الحلقة'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect((await app.store.getDoc('circles/cA'))!['assignedTeacherId'], 't2');
      expect((await app.store.getDoc('students/s1'))!['assignedTeacherIds'], ['t2']);
      expect((await app.store.getDoc('enrollments/e_s2'))!['teacherId'], 't2');
      expect((await app.store.getDoc('schedules/up1'))!['teacherId'], 't2');
      expect(find.text('تم حفظ التعديلات'), findsOneWidget);
      expect(find.text('المعلمة خديجة'), findsOneWidget); // detail page refreshed
    });

    testWidgets('capacity below the current students is refused with the reason', (tester) async {
      final app = await open(tester, '/director/circles/cA/edit');
      await tester.enterText(find.widgetWithText(TextField, 'السعة القصوى *'), '1');
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('السعة أقل من عدد الطلاب الحاليين (2)'), findsOneWidget);
      expect((await app.store.getDoc('circles/cA'))!['maxCapacity'], 5);
    });

    testWidgets('invalid input is explained before anything is sent', (tester) async {
      final app = await open(tester, '/director/circles/cA/edit');
      await tester.enterText(find.widgetWithText(TextField, 'اسم الحلقة *'), '  ');
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('اسم الحلقة مطلوب'), findsOneWidget);
      expect(await app.store.query('audit_logs', where: []), isEmpty);
    });

    testWidgets('another center\'s circle cannot be edited', (tester) async {
      await open(tester, '/director/circles/cX/edit');
      expect(find.text('الحلقة غير موجودة أو مؤرشفة'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'حفظ'), findsNothing);
    });
  });

  testWidgets('the circle list opens details and offers edit', (tester) async {
    await open(tester, '/director/circles');
    await tester.tap(find.text('حلقة الفجر'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحلقة'), findsOneWidget);
  });
}
