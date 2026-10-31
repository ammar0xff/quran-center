import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/user.dart';

User _user({
  String uid = 'u1',
  UserRole role = UserRole.teacher,
  AccountStatus status = AccountStatus.active,
  String? studentId,
}) =>
    User(
      uid: uid,
      centerId: 'center-1',
      fullName: 'مستخدم',
      role: role,
      status: status,
      authProvider: 'password',
      studentId: studentId ?? (role == UserRole.student ? 'stu-1' : null),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('resolveSession', () {
    test('no uid -> unauthenticated', () {
      expect(resolveSession(uid: null, profile: null).kind,
          SessionKind.unauthenticated);
    });

    test('active profiles resolve to their stored role', () {
      expect(
          resolveSession(uid: 'u1', profile: _user(role: UserRole.director)).kind,
          SessionKind.director);
      expect(
          resolveSession(uid: 'u1', profile: _user(role: UserRole.teacher)).kind,
          SessionKind.teacher);
      expect(
          resolveSession(uid: 'u1', profile: _user(role: UserRole.student)).kind,
          SessionKind.student);
    });

    test('a student login without a linked student profile is blocked', () {
      final profile = User(
        uid: 'u1', centerId: 'c', fullName: 'x', role: UserRole.student,
        status: AccountStatus.active, authProvider: 'password',
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
      );
      final s = resolveSession(uid: 'u1', profile: profile);
      expect(s.kind, SessionKind.blocked);
      expect(s.blockReason, BlockReason.incomplete);
    });

    test('signed in but no profile is blocked, not admitted', () {
      final s = resolveSession(uid: 'u1', profile: null);
      expect(s.kind, SessionKind.blocked);
      expect(s.blockReason, BlockReason.noProfile);
    });

    test('a profile belonging to a different uid is never trusted', () {
      final s = resolveSession(uid: 'u1', profile: _user(uid: 'someone-else'));
      expect(s.kind, SessionKind.blocked);
      expect(s.blockReason, BlockReason.noProfile);
    });

    test('inactive accounts are blocked with the matching reason', () {
      final expected = {
        AccountStatus.suspended: BlockReason.suspended,
        AccountStatus.pending: BlockReason.pending,
        AccountStatus.incomplete: BlockReason.incomplete,
      };
      for (final entry in expected.entries) {
        final s = resolveSession(
            uid: 'u1',
            profile: _user(role: UserRole.director, status: entry.key));
        expect(s.kind, SessionKind.blocked, reason: '${entry.key}');
        expect(s.blockReason, entry.value);
      }
    });

    test('active profile with expired subscription resolves to subscriptionExpired', () {
      final s = resolveSession(
        uid: 'u1',
        profile: _user(role: UserRole.director, status: AccountStatus.active),
        isSubscriptionExpired: true,
      );
      expect(s.kind, SessionKind.blocked);
      expect(s.blockReason, BlockReason.subscriptionExpired);
    });

    test('a suspended director gets no privileged access', () {
      final s = resolveSession(
          uid: 'u1',
          profile:
              _user(role: UserRole.director, status: AccountStatus.suspended));
      expect(s.isSignedInWithRole, isFalse);
    });

    test('guardian role is unsupported in this release', () {
      final s =
          resolveSession(uid: 'u1', profile: _user(role: UserRole.guardian));
      expect(s.kind, SessionKind.blocked);
      expect(s.blockReason, BlockReason.unsupportedRole);
    });
  });

  group('redirectFor', () {
    const loading = AppSession.loading();
    const anon = AppSession.unauthenticated();
    final director = AppSession.signedIn(SessionKind.director, _user());
    final teacher = AppSession.signedIn(SessionKind.teacher, _user());
    final student = AppSession.signedIn(SessionKind.student, _user());
    const blocked = AppSession.blocked(BlockReason.suspended);

    test('loading only ever shows the splash', () {
      expect(redirectFor(loading, Routes.splash), isNull);
      expect(redirectFor(loading, '/director/students'), Routes.splash);
      expect(redirectFor(loading, Routes.login), Routes.splash);
    });

    test('signed-out users can reach only login and forgot-password', () {
      expect(redirectFor(anon, Routes.login), isNull);
      expect(redirectFor(anon, Routes.forgotPassword), isNull);
      expect(redirectFor(anon, Routes.splash), Routes.login);
      expect(redirectFor(anon, '/director/dashboard'), Routes.login);
      expect(redirectFor(anon, '/teacher/home'), Routes.login);
      expect(redirectFor(anon, Routes.accountStatus), Routes.login);
    });

    test('blocked users can reach only the account-status screen', () {
      expect(redirectFor(blocked, Routes.accountStatus), isNull);
      expect(redirectFor(blocked, '/director/dashboard'), Routes.accountStatus);
      expect(redirectFor(blocked, Routes.login), Routes.accountStatus);
    });

    test('a director stays in /director and is bounced from other areas', () {
      expect(redirectFor(director, '/director/students/add'), isNull);
      expect(redirectFor(director, '/teacher/home'), Routes.directorHome);
      expect(redirectFor(director, '/student/home'), Routes.directorHome);
      expect(redirectFor(director, Routes.login), Routes.directorHome);
      expect(redirectFor(director, Routes.splash), Routes.directorHome);
    });

    test('teachers cannot open director screens', () {
      expect(redirectFor(teacher, '/teacher/home'), isNull);
      expect(redirectFor(teacher, '/director/students'), Routes.teacherHome);
      expect(redirectFor(teacher, '/director/attendance'), Routes.teacherHome);
    });

    test('students cannot open teacher or director screens', () {
      expect(redirectFor(student, '/student/home'), isNull);
      expect(redirectFor(student, '/teacher/home'), Routes.studentHome);
      expect(redirectFor(student, '/director/dashboard'), Routes.studentHome);
    });

    test('lookalike prefixes do not slip through', () {
      expect(redirectFor(teacher, '/directorate/x'), Routes.teacherHome);
      expect(redirectFor(student, '/teacherX'), Routes.studentHome);
    });

    test('subscriptionExpired directs to tasbeeh and allows pricing renewal', () {
      final expired = AppSession.blocked(BlockReason.subscriptionExpired,
          profile: _user(role: UserRole.director));
      expect(expired.homeRoute, Routes.tasbeeh);
      expect(redirectFor(expired, Routes.tasbeeh), isNull);
      expect(redirectFor(expired, Routes.pricing), isNull);
      expect(redirectFor(expired, Routes.directorHome), Routes.tasbeeh);
      expect(redirectFor(expired, Routes.login), Routes.tasbeeh);
    });

    test('homeRoute is always allowed by the guard', () {
      final expired = AppSession.blocked(BlockReason.subscriptionExpired,
          profile: _user(role: UserRole.director));
      for (final s in [director, teacher, student, blocked, anon, expired]) {
        expect(redirectFor(s, s.homeRoute!), isNull, reason: '${s.kind}');
      }
      expect(loading.homeRoute, isNull);
    });
  });
}

