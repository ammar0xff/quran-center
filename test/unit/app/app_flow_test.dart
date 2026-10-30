import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/app/app.dart';
import 'package:quran_center/app/router.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/user_repository.dart';

const _badCreds = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

/// In-memory authentication backend.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway(this.accounts);

  /// email -> (password, uid)
  final Map<String, (String, String)> accounts;
  final _changes = StreamController<String?>.broadcast();
  String? _uid;
  int signInCalls = 0;
  final resets = <String>[];

  @override
  Stream<String?> uidChanges() async* {
    yield _uid;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    final entry = accounts[email];
    if (entry == null || entry.$1 != password) throw AuthFailure(_badCreds);
    _uid = entry.$2;
    _changes.add(_uid);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _changes.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);
}

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
}

Future<void> _seedUser(
  FakeFirestoreDataSource store,
  String uid,
  String role, {
  String status = 'active',
}) =>
    store.setDoc('users/$uid', {
      'centerId': 'center-1',
      'fullName': 'مستخدم $uid',
      'role': role,
      'status': status,
      'authProvider': 'password',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    });

Future<(FakeAuthGateway, FakeFirestoreDataSource)> _boot(
  WidgetTester tester, {
  UserRepository? usersOverride,
}) async {
  final store = FakeFirestoreDataSource();
  await _seedUser(store, 'dir-1', 'director');
  await _seedUser(store, 'tea-1', 'teacher');
  await _seedUser(store, 'sus-1', 'director', status: 'suspended');
  await store.setDoc('users/dir-2', {
    'centerId': 'center-2',
    'fullName': 'مديرة المركز الثاني',
    'role': 'director',
    'status': 'active',
    'authProvider': 'password',
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
  });
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
  // 'ghost' authenticates but has no profile document.
  final gateway = FakeAuthGateway({
    'dir@x.com': ('pw-dir', 'dir-1'),
    'dir2@x.com': ('pw-dir2', 'dir-2'),
    'tea@x.com': ('pw-tea', 'tea-1'),
    'sus@x.com': ('pw-sus', 'sus-1'),
    'ghost@x.com': ('pw-ghost', 'ghost-1'),
  });

  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      firestoreDataSourceProvider.overrideWithValue(store),
      if (usersOverride != null) userRepositoryProvider.overrideWithValue(usersOverride),
    ],
    child: const App(),
  ));
  await tester.pumpAndSettle();
  return (gateway, store);
}

Future<void> _signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) {
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  return container.read(routerProvider);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('cold start with nobody signed in shows the login screen', (tester) async {
    await _boot(tester);
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text('أهلاً بك، مديرة الدار'), findsNothing);
  });

  testWidgets('invalid input is rejected without contacting the backend', (tester) async {
    final (gateway, _) = await _boot(tester);

    await _signIn(tester, 'not-an-email', '');
    expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);
    expect(gateway.signInCalls, 0);
  });

  testWidgets('wrong password shows a generic error and stays on login', (tester) async {
    final (gateway, _) = await _boot(tester);

    await _signIn(tester, 'dir@x.com', 'wrong');
    expect(find.text(_badCreds), findsOneWidget);
    expect(gateway.signInCalls, 1);
    expect(find.text('أهلاً بك، مديرة الدار'), findsNothing);
  });

  testWidgets('a director signs in and lands on the director dashboard', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'dir@x.com', 'pw-dir');
    expect(find.text('أهلاً بك، مديرة الدار'), findsOneWidget);
  });

  testWidgets('a teacher lands in the teacher area, never the director one', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'tea@x.com', 'pw-tea');
    expect(find.text('واجهة المعلم'), findsOneWidget);

    // Typing a director URL does not get a teacher in.
    _router(tester).go('/director/students');
    await tester.pumpAndSettle();
    expect(find.text('واجهة المعلم'), findsOneWidget);
    expect(find.text('إدارة الطلاب'), findsNothing);

    _router(tester).go('/director/attendance');
    await tester.pumpAndSettle();
    expect(find.text('إدارة الحضور'), findsNothing);
  });

  testWidgets('a suspended director is blocked and sees no dashboard', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'sus@x.com', 'pw-sus');

    expect(find.text('الحساب معلّق'), findsOneWidget);
    expect(find.text('أهلاً بك، مديرة الدار'), findsNothing);

    _router(tester).go('/director/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('الحساب معلّق'), findsOneWidget);
    expect(find.text('أهلاً بك، مديرة الدار'), findsNothing);
  });

  testWidgets('signing in without a profile is blocked, not admitted', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'ghost@x.com', 'pw-ghost');

    expect(find.text('لم يتم العثور على ملف الحساب'), findsOneWidget);
    expect(find.text('أهلاً بك، مديرة الدار'), findsNothing);
  });

  testWidgets('if the profile cannot be loaded the user can retry, not be told they have no account',
      (tester) async {
    await _boot(tester, usersOverride: _ThrowingUsers());
    await _signIn(tester, 'dir@x.com', 'pw-dir');

    expect(find.text('تعذر التحقق من حسابك'), findsOneWidget);
    expect(find.text('إعادة التحقق'), findsOneWidget);
    expect(find.text('لم يتم العثور على ملف الحساب'), findsNothing);
  });

  testWidgets('signed-out deep links go to login', (tester) async {
    await _boot(tester);
    _router(tester).go('/director/students/add');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text('إضافة طالب جديد'), findsNothing);
  });

  testWidgets('sign-out returns to login and the next user gets only their own area',
      (tester) async {
    await _boot(tester);
    await _signIn(tester, 'tea@x.com', 'pw-tea');
    expect(find.text('واجهة المعلم'), findsOneWidget);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(find.text('واجهة المعلم'), findsNothing);

    await _signIn(tester, 'dir@x.com', 'pw-dir');
    expect(find.text('أهلاً بك، مديرة الدار'), findsOneWidget);
    expect(find.text('واجهة المعلم'), findsNothing);
  });

  testWidgets('each director sees only their own center\'s students', (tester) async {
    await _boot(tester);

    await _signIn(tester, 'dir@x.com', 'pw-dir');
    _router(tester).go('/director/students');
    await tester.pumpAndSettle();
    expect(find.text('طالب المركز الأول'), findsOneWidget);
    expect(find.text('طالب المركز الثاني'), findsNothing);

    // Different center, same device, same store.
    await ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(authGatewayProvider)
        .signOut();
    await tester.pumpAndSettle();
    await _signIn(tester, 'dir2@x.com', 'pw-dir2');
    _router(tester).go('/director/students');
    await tester.pumpAndSettle();
    expect(find.text('طالب المركز الثاني'), findsOneWidget);
    expect(find.text('طالب المركز الأول'), findsNothing);
  });

  testWidgets('password reset gives the same confirmation for any address', (tester) async {
    final (gateway, _) = await _boot(tester);

    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'nobody@nowhere.com');
    await tester.tap(find.text('إرسال رابط الاستعادة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('إذا كان هذا البريد مسجلًا'), findsOneWidget);
    expect(gateway.resets, ['nobody@nowhere.com']);
  });
}
