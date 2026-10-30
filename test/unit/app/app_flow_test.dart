import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/repositories/user_repository.dart';

import '../../support/app_harness.dart';

class _ThrowingUsers implements UserRepository {
  @override
  Future<User?> getUser(String uid) async => throw StateError('offline');
  @override
  Future<void> createUser(User user) async {}
  @override
  Future<void> updateUser(User user) async {}
  @override
  Stream<List<User>> watchUsersByCenter(String centerId) => const Stream.empty();
  @override
  Future<List<User>> getUsersByCenter(String centerId) async => [];
  @override
  Future<List<User>> getAllUsersByCenter(String centerId) async => [];
}

const _accounts = {
  'dir@x.com': ('pw-dir', 'dir-1'),
  'dir2@x.com': ('pw-dir2', 'dir-2'),
  'tea@x.com': ('pw-tea', 'tea-1'),
  'sus@x.com': ('pw-sus', 'sus-1'),
  'ghost@x.com': ('pw-ghost', 'ghost-1'), // authenticates, has no profile
};

Future<void> _seed(FakeFirestoreDataSource store) async {
  await seedUser(store, 'dir-1', 'director', name: 'مديرة الدار');
  await seedUser(store, 'dir-2', 'director', centerId: 'center-2', name: 'مديرة المركز الثاني');
  await seedUser(store, 'tea-1', 'teacher');
  await seedUser(store, 'sus-1', 'director', status: 'suspended');
  for (final (id, center, name) in [
    ('s-1', 'center-1', 'طالب المركز الأول'),
    ('s-2', 'center-2', 'طالب المركز الثاني'),
  ]) {
    await store.setDoc('students/$id', {
      'centerId': center,
      'fullName': name,
      'accountMode': 'none',
      'enrollmentStatus': 'active',
      'assignedTeacherIds': [],
      'educationalLevel': 'مبتدئ',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    });
  }
}

const _welcome = 'مديرة الدار';
const _teacherWelcome = 'مستخدم tea-1';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('cold start with nobody signed in shows the login screen', (tester) async {
    await bootApp(tester, accounts: _accounts, seed: _seed);
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text(_welcome), findsNothing);
  });

  testWidgets('invalid input is rejected without contacting the backend', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);

    await app.signIn('not-an-email', '');
    expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);
    expect(app.gateway.signInCalls, 0);
  });

  testWidgets('wrong password shows a generic error and stays on login', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);

    await app.signIn('dir@x.com', 'wrong');
    expect(find.text(badCredentialsMessage), findsOneWidget);
    expect(app.gateway.signInCalls, 1);
    expect(find.text(_welcome), findsNothing);
  });

  testWidgets('a director signs in and lands on the director dashboard', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw-dir');
    expect(find.text(_welcome), findsOneWidget);
  });

  testWidgets('a teacher lands in the teacher area, never the director one', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('tea@x.com', 'pw-tea');
    expect(find.text(_teacherWelcome), findsOneWidget);

    await app.go('/director/students');
    expect(find.text(_teacherWelcome), findsOneWidget);
    expect(find.text('إدارة الطلاب'), findsNothing);

    await app.go('/director/attendance');
    expect(find.text('إدارة الحضور'), findsNothing);
  });

  testWidgets('a suspended director is blocked and sees no dashboard', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('sus@x.com', 'pw-sus');

    expect(find.text('الحساب معلّق'), findsOneWidget);
    expect(find.text(_welcome), findsNothing);

    await app.go('/director/dashboard');
    expect(find.text('الحساب معلّق'), findsOneWidget);
    expect(find.text(_welcome), findsNothing);
  });

  testWidgets('signing in without a profile is blocked, not admitted', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('ghost@x.com', 'pw-ghost');

    expect(find.text('لم يتم العثور على ملف الحساب'), findsOneWidget);
    expect(find.text(_welcome), findsNothing);
  });

  testWidgets('if the profile cannot be loaded the user can retry, not be told they have no account',
      (tester) async {
    final app = await bootApp(tester,
        accounts: _accounts, seed: _seed, usersOverride: _ThrowingUsers());
    await app.signIn('dir@x.com', 'pw-dir');

    expect(find.text('تعذر التحقق من حسابك'), findsOneWidget);
    expect(find.text('إعادة التحقق'), findsOneWidget);
    expect(find.text('لم يتم العثور على ملف الحساب'), findsNothing);
  });

  testWidgets('signed-out deep links go to login', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.go('/director/students/add');
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text('إضافة طالب جديد'), findsNothing);
  });

  testWidgets('sign-out returns to login and the next user gets only their own area',
      (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('tea@x.com', 'pw-tea');
    expect(find.text(_teacherWelcome), findsOneWidget);

    await tester.tap(find.text('المزيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text(_teacherWelcome), findsNothing);

    await app.signIn('dir@x.com', 'pw-dir');
    expect(find.text(_welcome), findsOneWidget);
    expect(find.text(_teacherWelcome), findsNothing);
  });

  testWidgets("each director sees only their own center's students", (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);

    await app.signIn('dir@x.com', 'pw-dir');
    await app.go('/director/students');
    expect(find.text('طالب المركز الأول'), findsOneWidget);
    expect(find.text('طالب المركز الثاني'), findsNothing);

    await app.signOut();
    await app.signIn('dir2@x.com', 'pw-dir2');
    await app.go('/director/students');
    expect(find.text('طالب المركز الثاني'), findsOneWidget);
    expect(find.text('طالب المركز الأول'), findsNothing);
  });

  testWidgets('password reset gives the same confirmation for any address', (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);

    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'nobody@nowhere.com');
    await tester.tap(find.text('إرسال رابط الاستعادة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('إذا كان هذا البريد مسجلًا'), findsOneWidget);
    expect(app.gateway.resets, ['nobody@nowhere.com']);
  });
}
