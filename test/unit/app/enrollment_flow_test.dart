import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  Future<void> student(String id, String name, String center, String status) =>
      s.setDoc('students/$id', {
        'centerId': center,
        'fullName': name,
        'accountMode': 'none',
        'enrollmentStatus': status,
        'assignedTeacherIds': <String>[],
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await student('s1', 'أحمد علي', 'center-1', 'active');
  await student('s2', 'بسمة خالد', 'center-1', 'active');
  await student('s3', 'جميلة سعيد', 'center-1', 'archived');
  await student('s4', 'طالب مركز آخر', 'center-2', 'active');

  Future<void> circle(String id, String name, String center, String status,
          {int cap = 5, String? teacher}) =>
      s.setDoc('circles/$id', {
        'centerId': center,
        'name': name,
        'educationalLevel': 'مبتدئ',
        'assignedTeacherId': teacher,
        'maxCapacity': cap,
        'locationOrMode': 'onsite',
        'weeklySchedule': [],
        'sessionDurationMinutes': 60,
        'status': status,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 'center-1', 'active', teacher: 't1');
  await circle('cB', 'حلقة المغرب', 'center-1', 'active', cap: 1);
  await circle('cOld', 'حلقة قديمة', 'center-1', 'archived');
  await circle('cX', 'حلقة مركز آخر', 'center-2', 'active');
  await s.setDoc('teachers/t1', {
    'centerId': 'center-1',
    'userId': 't1',
    'fullName': 'المعلمة فاطمة',
    'status': 'active',
    'assignedCircleIds': [],
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
  });
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, [String path = '/director/enrollments/assign']) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go(path);
    return app;
  }

  testWidgets('offers only active students and circles of this center', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'الطالب *'));
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsWidgets);
    expect(find.text('بسمة خالد'), findsWidgets);
    expect(find.text('جميلة سعيد'), findsNothing); // archived
    expect(find.text('طالب مركز آخر'), findsNothing); // other center
    await tester.tap(find.text('بسمة خالد').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'الحلقة *'));
    await tester.pumpAndSettle();
    expect(find.textContaining('حلقة الفجر'), findsWidgets);
    expect(find.textContaining('حلقة قديمة'), findsNothing);
    expect(find.textContaining('حلقة مركز آخر'), findsNothing);
  });

  testWidgets('submitting without choices explains what is missing and writes nothing',
      (tester) async {
    final app = await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();
    expect(find.text('اختر الطالب والحلقة أولًا.'), findsOneWidget);
    expect(await app.store.query('enrollments', where: []), isEmpty);
  });

  testWidgets('assigns the student, adopts the circle teacher and audits', (tester) async {
    final app = await open(tester);
    await _choose(tester, 'الطالب *', 'أحمد علي');
    await _choose(tester, 'الحلقة *', 'حلقة الفجر');
    expect(find.text('معلم الحلقة: المعلمة فاطمة'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();

    final enrollments = await app.store.query('enrollments', where: []);
    expect(enrollments, hasLength(1));
    expect(enrollments.single['studentId'], 's1');
    expect(enrollments.single['circleId'], 'cA');
    expect(enrollments.single['status'], 'active');
    expect((await app.store.getDoc('students/s1'))!['assignedTeacherIds'], ['t1']);
    final audit = await app.store.query('audit_logs', where: []);
    expect(audit.single['actorUserId'], 'dir-1');
    expect(audit.single['action'], 'assign_student');

    expect(find.text('تم تعيين الطالب للحلقة'), findsOneWidget);
    expect(find.text('إدارة الطلاب'), findsOneWidget);
  });

  testWidgets('a full circle is refused with a clear message', (tester) async {
    final app = await open(tester);
    await _choose(tester, 'الطالب *', 'أحمد علي');
    await _choose(tester, 'الحلقة *', 'حلقة المغرب');
    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();
    expect(await app.store.query('enrollments', where: []), hasLength(1));

    // Circle cB has capacity 1 and is now full: a second student is refused.
    await app.go('/director/enrollments/assign');
    await _choose(tester, 'الطالب *', 'بسمة خالد');
    await _choose(tester, 'الحلقة *', 'حلقة المغرب');
    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();

    expect(find.textContaining('الحلقة ممتلئة'), findsOneWidget);
    expect(await app.store.query('enrollments', where: []), hasLength(1));
    // Form is still usable.
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'تعيين'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('moving a student warns first, then transfers and keeps history',
      (tester) async {
    final app = await open(tester);
    await _choose(tester, 'الطالب *', 'أحمد علي');
    await _choose(tester, 'الحلقة *', 'حلقة الفجر');
    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();

    await app.go('/director/enrollments/assign');
    await _choose(tester, 'الطالب *', 'أحمد علي');
    expect(find.textContaining('مسجّل حاليًا في «حلقة الفجر»'), findsOneWidget);
    await _choose(tester, 'الحلقة *', 'حلقة المغرب');
    await tester.tap(find.widgetWithText(FilledButton, 'تعيين'));
    await tester.pumpAndSettle();

    final all = await app.store.query('enrollments', where: []);
    expect(all, hasLength(2));
    expect(all.singleWhere((e) => e['circleId'] == 'cA')['status'], 'transferred');
    expect(all.singleWhere((e) => e['circleId'] == 'cB')['status'], 'active');
    expect((await app.store.getDoc('students/s1'))!['assignedTeacherIds'], isEmpty);
  });

  testWidgets('opened from a student menu, that student is preselected', (tester) async {
    final app = await open(tester, '/director/students');
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'بسمة خالد'),
        matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعيين لحلقة'));
    await tester.pumpAndSettle();

    expect(find.text('تعيين الطالب للحلقة'), findsOneWidget);
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(await app.store.query('enrollments', where: []), isEmpty);
  });

  testWidgets('with no circles the screen says so instead of an empty form', (tester) async {
    final app = await bootApp(tester,
        accounts: _accounts,
        seed: (s) async {
          await seedUser(s, 'dir-1', 'director');
          await s.setDoc('students/s1', {
            'centerId': 'center-1',
            'fullName': 'أحمد',
            'accountMode': 'none',
            'enrollmentStatus': 'active',
            'assignedTeacherIds': <String>[],
            'educationalLevel': 'x',
            'createdAt': 1700000000000,
            'updatedAt': 1700000000000,
          });
        });
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/enrollments/assign');
    expect(find.textContaining('لا توجد حلقات نشطة'), findsOneWidget);
    expect(find.text('إنشاء حلقة'), findsOneWidget);
  });
}
