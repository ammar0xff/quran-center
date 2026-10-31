import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/services/account_access_service.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  Future<void> teacher(String id, String center, String name, String status,
          {List<String> circles = const []}) =>
      s.setDoc('teachers/$id', {
        'centerId': center,
        'userId': id,
        'fullName': name,
        'status': status,
        'assignedCircleIds': circles,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await teacher('t1', 'center-1', 'فاطمة علي', 'active');
  // The count comes from the circles themselves: two active ones count, the
  // archived one and the other teacher's do not.
  Future<void> circle(String id, String? teacherId, String status) =>
      s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': 'حلقة $id', 'educationalLevel': 'x',
        'assignedTeacherId': teacherId, 'maxCapacity': 10, 'locationOrMode': 'onsite',
        'weeklySchedule': [], 'sessionDurationMinutes': 60, 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('c1', 't1', 'active');
  await circle('c2', 't1', 'active');
  await circle('c3', 't1', 'archived');
  await circle('c4', 't2', 'active');
  await teacher('t2', 'center-1', 'خديجة حسن', 'suspended');
  await teacher('t3', 'center-2', 'معلمة مركز آخر', 'active');
}

Finder _menuOf(String name) => find.descendant(
    of: find.widgetWithText(ListTile, name), matching: find.byType(PopupMenuButton<String>));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<(AppHarness, RecordingAccessService)> open(WidgetTester tester, String path) async {
    final access = RecordingAccessService();
    final app = await bootApp(tester,
        accounts: _accounts, seed: _seed, accessService: access);
    await app.signIn('dir@x.com', 'pw');
    await app.go(path);
    return (app, access);
  }

  group('add teacher', () {
    testWidgets('blank or malformed input is rejected before any request', (tester) async {
      final (_, access) = await open(tester, '/director/teachers/add');
      await tester.tap(find.text('بريد إلكتروني تقليدي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني الشخصي *'), 'nope');
      await tester.tap(find.text('إنشاء حساب المعلم'));
      await tester.pumpAndSettle();

      expect(find.text('الاسم مطلوب'), findsOneWidget);
      expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
      expect(access.calls, isEmpty);
    });

    testWidgets('a valid teacher is sent to the backend, then listed', (tester) async {
      final (_, access) = await open(tester, '/director/teachers/add');
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), '  مريم   أحمد ');
      await tester.tap(find.text('بريد إلكتروني تقليدي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني الشخصي *'), 'maryam@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'الجوال (اختياري)'), '0500000000');
      await tester.tap(find.text('إنشاء حساب المعلم'));
      await tester.pumpAndSettle();

      // The screen passes the raw text; the backend trims and normalises it.
      expect(access.calls, hasLength(1));
      expect(access.calls.single, startsWith('createTeacher:'));
      expect(access.calls.single, contains('maryam@example.com'));
      expect(access.calls.single, contains('0500000000'));
      expect(find.text('تم إنشاء حساب المعلم وإرسال رسالة التفعيل'), findsOneWidget);
      expect(find.text('إدارة المعلمين'), findsOneWidget); // landed on the list
    });

    testWidgets('creating a teacher with meshkah direct identity sends username@center.meshkah', (tester) async {
      final (_, access) = await open(tester, '/director/teachers/add');
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'فاطمة محمد');
      await tester.enterText(find.widgetWithText(TextFormField, 'اسم المستخدم بالإنجليزية *'), 'fatima');
      await tester.tap(find.text('إنشاء حساب المعلم'));
      await tester.pumpAndSettle();

      expect(access.calls, hasLength(1));
      expect(access.calls.single, startsWith('createTeacher:'));
      expect(access.calls.single, contains('fatima@center-1.meshkah'));
      expect(find.text('تم إنشاء حساب المعلم وإرسال رسالة التفعيل'), findsOneWidget);
    });

    testWidgets('a backend refusal is shown, the form is kept, and retry is possible',
        (tester) async {
      final (_, access) = await open(tester, '/director/teachers/add');
      access.failWith =
          AccountAccessException('هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.');
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'مريم أحمد');
      await tester.tap(find.text('بريد إلكتروني تقليدي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني الشخصي *'), 'taken@example.com');
      await tester.tap(find.text('إنشاء حساب المعلم'));
      await tester.pumpAndSettle();

      expect(find.text('هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.'), findsOneWidget);
      expect(find.text('مريم أحمد'), findsOneWidget); // typed text kept
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إنشاء حساب المعلم'));
      expect(button.onPressed, isNotNull); // can correct the email and retry
    });

    testWidgets('if only the activation email fails, the account is not re-created',
        (tester) async {
      final (_, access) = await open(tester, '/director/teachers/add');
      access.failWith = ActivationEmailException();
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'مريم أحمد');
      await tester.tap(find.text('بريد إلكتروني تقليدي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني الشخصي *'), 'm@example.com');
      await tester.tap(find.text('إنشاء حساب المعلم'));
      await tester.pumpAndSettle();

      expect(access.calls, hasLength(1));
      expect(find.textContaining('تعذر إرسال رسالة التفعيل'), findsOneWidget);
      expect(find.text('إدارة المعلمين'), findsOneWidget); // moved on to the list
    });
  });

  group('teacher list', () {
    testWidgets("shows this center's teachers with status and circle counts", (tester) async {
      await open(tester, '/director/teachers');
      expect(find.text('فاطمة علي'), findsOneWidget);
      expect(find.text('خديجة حسن'), findsOneWidget);
      expect(find.text('معلمة مركز آخر'), findsNothing);
      expect(find.text('2 حلقة'), findsOneWidget);
      expect(find.text('1 حلقة'), findsOneWidget); // t2 has one circle
      expect(find.text('بدون حلقات'), findsNothing);
    });

    testWidgets('search and status filters work and can be cleared', (tester) async {
      await open(tester, '/director/teachers');
      await tester.tap(find.widgetWithText(ChoiceChip, 'معلّق'));
      await tester.pumpAndSettle();
      expect(find.text('خديجة حسن'), findsOneWidget);
      expect(find.text('فاطمة علي'), findsNothing);

      await tester.enterText(find.byType(TextField), 'لا أحد');
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد معلمون مطابقون'), findsOneWidget);

      await tester.tap(find.text('مسح البحث والفلاتر'));
      await tester.pumpAndSettle();
      expect(find.text('فاطمة علي'), findsOneWidget);
      expect(find.text('خديجة حسن'), findsOneWidget);
    });

    testWidgets('suspending asks first; cancel does nothing, confirm calls the backend',
        (tester) async {
      final (_, access) = await open(tester, '/director/teachers');

      await tester.tap(_menuOf('فاطمة علي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعليق الدخول').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('تبقى سجلاته'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(access.calls, isEmpty);

      await tester.tap(_menuOf('فاطمة علي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعليق الدخول').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تعليق'));
      await tester.pumpAndSettle();

      expect(access.calls, ['suspendTeacher:t1:true']);
      expect(find.text('تم تعليق المعلم'), findsOneWidget);
    });

    testWidgets('a suspended teacher can be reactivated', (tester) async {
      final (_, access) = await open(tester, '/director/teachers');
      await tester.tap(_menuOf('خديجة حسن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعادة تفعيل').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'إعادة التفعيل'));
      await tester.pumpAndSettle();
      expect(access.calls, ['suspendTeacher:t2:false']);
    });

    testWidgets('a backend failure on suspend is reported, not swallowed', (tester) async {
      final (_, access) = await open(tester, '/director/teachers');
      access.failWith = AccountAccessException('ليست لديك صلاحية تنفيذ هذا الإجراء.');
      await tester.tap(_menuOf('فاطمة علي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعليق الدخول').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تعليق'));
      await tester.pumpAndSettle();
      expect(find.text('ليست لديك صلاحية تنفيذ هذا الإجراء.'), findsOneWidget);
    });
  });
}
