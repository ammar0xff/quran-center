import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/services/account_access_service.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director', name: 'مديرة الدار');
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  await seedUser(s, 'tea-2', 'teacher', name: 'المعلمة خديجة', status: 'suspended');
  await seedUser(s, 'u-s1', 'student', name: 'بسمة خالد', studentId: 's1');
  await seedUser(s, 'u-x', 'teacher', name: 'معلم مركز آخر', centerId: 'center-2');
  await s.setDoc('teachers/tea-1', {
    'centerId': 'center-1', 'userId': 'tea-1', 'fullName': 'المعلمة فاطمة', 'status': 'active',
    'contactInfo': {'email': 'fatima@example.com'}, 'assignedCircleIds': [],
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<(AppHarness, RecordingAccessService)> open(WidgetTester tester) async {
    final access = RecordingAccessService();
    final app = await bootApp(tester, accounts: _accounts, seed: _seed, accessService: access);
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/accounts');
    return (app, access);
  }

  testWidgets('lists this center\'s accounts of every status, never another center\'s', (tester) async {
    await open(tester);
    expect(find.text('المعلمة فاطمة'), findsOneWidget);
    expect(find.text('المعلمة خديجة'), findsOneWidget); // suspended still listed
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('معلم مركز آخر'), findsNothing);
  });

  testWidgets('role and status filters narrow the list', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'الطلاب'));
    await tester.pumpAndSettle();
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('المعلمة فاطمة'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'المعلمون'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'معلّق'));
    await tester.pumpAndSettle();
    expect(find.text('المعلمة خديجة'), findsOneWidget);
    expect(find.text('المعلمة فاطمة'), findsNothing);
  });

  testWidgets('an activation email can be re-sent to an active teacher with a known email', (tester) async {
    final (_, access) = await open(tester);
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'المعلمة فاطمة'), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة إرسال رسالة التفعيل'));
    await tester.pumpAndSettle();
    expect(access.calls, ['resend:fatima@example.com']);
    expect(find.text('أُرسلت رسالة التفعيل'), findsOneWidget);
  });

  testWidgets('a suspended teacher has no resend option', (tester) async {
    await open(tester);
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'المعلمة خديجة'), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    expect(find.text('إعادة إرسال رسالة التفعيل'), findsNothing);
  });

  testWidgets('a failed resend is reported', (tester) async {
    final (_, access) = await open(tester);
    access.failWith = ActivationEmailException();
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'المعلمة فاطمة'), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة إرسال رسالة التفعيل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر إرسال رسالة التفعيل'), findsOneWidget);
  });

  testWidgets('a student account opens their profile', (tester) async {
    await open(tester);
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'بسمة خالد'), matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(find.text('ملف الطالب'), findsOneWidget);
  });
}
