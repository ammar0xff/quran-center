import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/core/finance/money.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1'), 'tea@x.com': ('pw', 'tea-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  for (final (id, name) in [('s1', 'بسمة خالد'), ('s2', 'أحمد علي')]) {
    await s.setDoc('students/$id', {
      'centerId': 'center-1', 'fullName': name, 'accountMode': 'none', 'enrollmentStatus': 'active',
      'assignedTeacherIds': [], 'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('student_fees/s1', {'centerId': 'center-1', 'studentId': 's1', 'monthlyFee': 15000});
  await s.setDoc('teachers/tea-1', {
    'centerId': 'center-1', 'userId': 'tea-1', 'fullName': 'المعلمة فاطمة', 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  await s.setDoc('wage_rates/tea-1', {'centerId': 'center-1', 'teacherId': 'tea-1', 'monthlyAmount': 300000});
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/finance');
    return app;
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Tab, name));
    await tester.pumpAndSettle();
  }

  testWidgets('the director issues the month, takes a part payment, and sees what remains', (tester) async {
    final app = await open(tester);
    expect(find.text(monthLabel(monthKey(DateTime.now()))), findsOneWidget);
    expect(find.textContaining('طالبًا بلا رسوم محددة'), findsOneWidget); // s2 has no fee

    await tester.tap(find.text('إصدار اشتراكات الشهر'));
    await tester.pumpAndSettle();
    expect(find.text('أُصدر 1 اشتراكًا.'), findsOneWidget);
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.textContaining('غير مدفوع'), findsOneWidget);

    await tester.tap(find.text('بسمة خالد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ ($currencyLabel) *'), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل'));
    await tester.pumpAndSettle();

    final sub = (await app.store.query('subscriptions', where: [])).single;
    expect(sub['amountPaid'], 10000);
    expect((await app.store.query('payments', where: [])).single['receivedBy'], 'dir-1');
    expect(find.textContaining('مدفوع جزئيًا'), findsOneWidget);
    expect(find.textContaining('المتبقي ${formatAmount(5000)}'), findsOneWidget);
  });

  testWidgets('a bad amount is refused and nothing is recorded', (tester) async {
    final app = await open(tester);
    await tester.tap(find.text('إصدار اشتراكات الشهر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بسمة خالد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ ($currencyLabel) *'), '12.345');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل مبلغًا صحيحًا'), findsOneWidget);
    expect(await app.store.query('payments', where: []), isEmpty);
  });

  testWidgets('a payment can be voided with a reason, and the balance comes back', (tester) async {
    final app = await open(tester);
    await tester.tap(find.text('إصدار اشتراكات الشهر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بسمة خالد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل')); // amount prefilled with what is owed
    await tester.pumpAndSettle();
    expect(find.textContaining('مدفوع'), findsWidgets);

    await tester.tap(find.text('بسمة خالد'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'سبب الإلغاء *'), 'خطأ في الإدخال');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect((await app.store.query('subscriptions', where: [])).single['amountPaid'], 0);
    final p = (await app.store.query('payments', where: [])).single;
    expect([p['voided'], p['voidReason']], [true, 'خطأ في الإدخال']);
    expect(find.textContaining('غير مدفوع'), findsOneWidget);
  });

  testWidgets('an expense is recorded, listed, totalled, and voidable', (tester) async {
    final app = await open(tester);
    await tab(tester, 'المصروفات');
    expect(find.text('لا توجد مصروفات في هذا الشهر.'), findsOneWidget);
    await tester.tap(find.text('تسجيل مصروف'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ ($currencyLabel) *'), '2500');
    await tester.enterText(find.widgetWithText(TextField, 'البيان (اختياري)'), 'إيجار الدار');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل'));
    await tester.pumpAndSettle();

    final e = (await app.store.query('expenses', where: [])).single;
    expect([e['category'], e['amount'], e['recordedBy']], ['rent', 250000, 'dir-1']);
    expect(find.textContaining('إجمالي المصروفات: ${formatAmount(250000)}'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'سبب الإلغاء *'), 'مكرر');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect((await app.store.query('expenses', where: [])).single['voided'], true);
    expect(find.textContaining('إجمالي المصروفات: ${formatAmount(0)}'), findsOneWidget);
  });

  testWidgets('wages: issue at the agreed rate, deduct with a reason, pay', (tester) async {
    final app = await open(tester);
    await tab(tester, 'الأجور');
    await tester.tap(find.text('إصدار أجور الشهر'));
    await tester.pumpAndSettle();
    expect(find.text('المعلمة فاطمة'), findsOneWidget);
    expect(find.textContaining('الأجر ${formatAmount(300000)}'), findsOneWidget);

    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خصم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ ($currencyLabel) *'), '200');
    await tester.enterText(find.widgetWithText(TextField, 'السبب *'), 'غياب يومين');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect((await app.store.query('wages', where: [])).single['amount'], 280000);

    await tester.tap(find.widgetWithText(FilledButton, 'دفع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الدفع'));
    await tester.pumpAndSettle();
    final w = (await app.store.query('wages', where: [])).single;
    expect([w['status'], w['paidBy']], ['paid', 'dir-1']);
    expect(find.text('مدفوع'), findsOneWidget);
  });

  testWidgets('the summary adds up the month and explains what the cash figure leaves out', (tester) async {
    await open(tester);
    await tester.tap(find.text('إصدار اشتراكات الشهر'));
    await tester.pumpAndSettle();
    await tab(tester, 'الملخص');
    expect(find.text('اشتراكات الشهر المصدَرة'), findsOneWidget);
    expect(find.text(formatAmount(15000)), findsWidgets);
    expect(find.textContaining('لا يدخل فيه ما هو مستحق'), findsOneWidget);
  });

  testWidgets('a teacher cannot open the finance screen', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('tea@x.com', 'pw');
    await app.go('/director/finance');
    expect(find.text('المالية'), findsNothing);
    expect(find.textContaining('أهلاً بك'), findsOneWidget);
  });
}
