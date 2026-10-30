import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  Future<void> student(String id, String name, String status, {String mode = 'none'}) =>
      s.setDoc('students/$id', {
        'centerId': 'center-1',
        'fullName': name,
        'accountMode': mode,
        'enrollmentStatus': status,
        'assignedTeacherIds': [],
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await student('id-a', 'أحمد علي', 'active');
  await student('id-b', 'بسمة خالد', 'active', mode: 'loginEnabled');
  await student('id-c', 'جميلة سعيد', 'archived');
}

Finder _menuOf(String name) => find.descendant(
    of: find.widgetWithText(ListTile, name),
    matching: find.byType(PopupMenuButton<String>));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/students');
    return app;
  }

  testWidgets('shows active students by default; filters switch the view', (tester) async {
    await open(tester);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('جميلة سعيد'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'مؤرشف'));
    await tester.pumpAndSettle();
    expect(find.text('جميلة سعيد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(find.text('جميلة سعيد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
  });

  testWidgets('login filter separates accountless students', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'لديه دخول'));
    await tester.pumpAndSettle();
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'بدون دخول'));
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('بسمة خالد'), findsNothing);
  });

  testWidgets('search narrows the list and can be cleared', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'بسمة');
    await tester.pumpAndSettle();
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsNothing);

    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد طلاب مطابقون'), findsOneWidget);

    await tester.tap(find.text('مسح البحث والفلاتر'));
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('جميلة سعيد'), findsOneWidget); // filters cleared too
  });

  testWidgets('a student can be found by their id', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'id-b');
    await tester.pumpAndSettle();
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsNothing);
  });

  testWidgets('tapping a student opens their profile; Add opens the form', (tester) async {
    final app = await open(tester);
    await tester.tap(find.text('أحمد علي'));
    await tester.pumpAndSettle();
    expect(find.text('ملف الطالب'), findsOneWidget);

    app.router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة طالب'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة طالب جديد'), findsOneWidget);
  });

  testWidgets('archive asks first; cancel changes nothing; confirm archives with an audit entry',
      (tester) async {
    final app = await open(tester);

    Future<void> chooseArchive() async {
      await tester.tap(_menuOf('أحمد علي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أرشفة').last);
      await tester.pumpAndSettle();
    }

    await chooseArchive();
    expect(find.textContaining('يبقى سجله الكامل'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect((await app.store.getDoc('students/id-a'))!['enrollmentStatus'], 'active');
    expect(await app.store.query('audit_logs', where: []), isEmpty);

    await chooseArchive();
    await tester.tap(find.widgetWithText(FilledButton, 'أرشفة'));
    await tester.pumpAndSettle();

    expect((await app.store.getDoc('students/id-a'))!['enrollmentStatus'], 'archived');
    expect(find.text('أحمد علي'), findsNothing); // gone from the active view
    expect(find.text('تمت أرشفة الطالب'), findsOneWidget);

    final audit = await app.store.query('audit_logs', where: []);
    expect(audit, hasLength(1));
    expect(audit.single['action'], 'archive_student');
    expect(audit.single['actorUserId'], 'dir-1');
    expect(audit.single['actorRole'], 'director');
    expect(audit.single['centerId'], 'center-1');
  });

  testWidgets('an archived student can be reinstated', (tester) async {
    final app = await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'مؤرشف'));
    await tester.pumpAndSettle();

    await tester.tap(_menuOf('جميلة سعيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة تفعيل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إعادة التفعيل'));
    await tester.pumpAndSettle();

    expect((await app.store.getDoc('students/id-c'))!['enrollmentStatus'], 'active');
    final audit = await app.store.query('audit_logs', where: []);
    expect(audit.single['action'], 'reinstate_student');
  });

  testWidgets('an archived student cannot be assigned to a circle from the menu',
      (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'مؤرشف'));
    await tester.pumpAndSettle();
    await tester.tap(_menuOf('جميلة سعيد'));
    await tester.pumpAndSettle();
    expect(find.text('تعيين لحلقة'), findsNothing);
    expect(find.text('أرشفة'), findsNothing);
  });
}
