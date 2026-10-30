import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/app/app.dart';
import 'package:quran_center/app/router.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/user_repository.dart';
import 'package:quran_center/data/services/account_access_service.dart';

const badCredentialsMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

/// In-memory authentication backend for tests.
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
    if (entry == null || entry.$1 != password) {
      throw AuthFailure(badCredentialsMessage);
    }
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

/// Writes a `users/{uid}` profile the way provisioning would.
Future<void> seedUser(
  FakeFirestoreDataSource store,
  String uid,
  String role, {
  String centerId = 'center-1',
  String status = 'active',
  String? name,
  String? studentId,
}) =>
    store.setDoc('users/$uid', {
      'centerId': centerId,
      'fullName': name ?? 'مستخدم $uid',
      'role': role,
      'status': status,
      'authProvider': 'password',
      if (studentId != null) 'studentId': studentId,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    });

class AppHarness {
  AppHarness(this.tester, this.gateway, this.store);

  final WidgetTester tester;
  final FakeAuthGateway gateway;
  final FakeFirestoreDataSource store;

  GoRouter get router => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(routerProvider);

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  Future<void> signIn(String email, String password) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();
  }

  Future<void> go(String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> signOut() async {
    await container.read(authGatewayProvider).signOut();
    await tester.pumpAndSettle();
  }
}

/// Boots the REAL [App] (router, session, guards) on a tall test screen.
///
/// [seed] fills the shared in-memory store before the app starts.
Future<AppHarness> bootApp(
  WidgetTester tester, {
  required Map<String, (String, String)> accounts,
  Future<void> Function(FakeFirestoreDataSource store)? seed,
  UserRepository? usersOverride,
  AccountAccessService? accessService,
  FakeFirestoreDataSource? store,
}) async {
  final db = store ?? FakeFirestoreDataSource();
  if (seed != null) await seed(db);
  final gateway = FakeAuthGateway(accounts);

  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      firestoreDataSourceProvider.overrideWithValue(db),
      if (usersOverride != null) userRepositoryProvider.overrideWithValue(usersOverride),
      if (accessService != null) accountAccessServiceProvider.overrideWithValue(accessService),
    ],
    child: const App(),
  ));
  await tester.pumpAndSettle();
  return AppHarness(tester, gateway, db);
}

/// Records access-service calls; optionally fails them.
class RecordingAccessService implements AccountAccessService {
  final calls = <String>[];
  Object? failWith;

  void _record(String call) {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> enableStudentAccess(
          {required String studentId, required String email}) async =>
      _record('enableStudent:$studentId:$email');

  @override
  Future<void> setSuspended(
          {required String studentId, required bool suspend}) async =>
      _record('suspendStudent:$studentId:$suspend');

  @override
  Future<void> createTeacher({
    required String fullName,
    required String email,
    String? phone,
    String? professionalNotes,
  }) async =>
      _record('createTeacher:$fullName:$email:${phone ?? ''}:${professionalNotes ?? ''}');

  @override
  Future<void> setTeacherSuspended(
          {required String teacherId, required bool suspend}) async =>
      _record('suspendTeacher:$teacherId:$suspend');

  @override
  Future<void> resendActivation(String email) async => _record('resend:$email');
}
