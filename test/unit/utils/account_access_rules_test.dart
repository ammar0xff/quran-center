import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

Student _s({
  AccountMode mode = AccountMode.none,
  String? uid,
  EnrollmentStatus status = EnrollmentStatus.active,
}) =>
    Student(
      studentId: 's1',
      centerId: 'center-1',
      fullName: 'طالب',
      enrollmentStatus: status,
      accountMode: mode,
      authUserId: uid,
      educationalLevel: 'مبتدئ',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('enable', () {
    test('allowed for an accountless active student', () {
      expect(checkAccessAction(_s(), AccessAction.enable), isNull);
    });
    test('blocked when a login already exists', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.loginEnabled, uid: 'u1'), AccessAction.enable),
        AccessBlock.alreadyHasLogin,
      );
    });
    test('blocked for suspended access (reactivate instead)', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.suspended, uid: 'u1'), AccessAction.enable),
        AccessBlock.alreadyHasLogin,
      );
    });
    test('blocked when a link exists even if mode says none', () {
      expect(checkAccessAction(_s(uid: 'u1'), AccessAction.enable),
          AccessBlock.alreadyHasLogin);
    });
    test('blocked for archived students', () {
      expect(
        checkAccessAction(
            _s(status: EnrollmentStatus.archived), AccessAction.enable),
        AccessBlock.archivedStudent,
      );
    });
  });

  group('suspend', () {
    test('allowed for an enabled, linked account', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.loginEnabled, uid: 'u1'), AccessAction.suspend),
        isNull,
      );
    });
    test('blocked when there is no login', () {
      expect(checkAccessAction(_s(), AccessAction.suspend),
          AccessBlock.noLoginToChange);
    });
    test('blocked when already suspended', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.suspended, uid: 'u1'), AccessAction.suspend),
        AccessBlock.alreadySuspended,
      );
    });
    test('blocked when enabled but the link is missing', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.loginEnabled), AccessAction.suspend),
        AccessBlock.missingLink,
      );
    });
  });

  group('reactivate', () {
    test('allowed only from suspended with a link', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.suspended, uid: 'u1'), AccessAction.reactivate),
        isNull,
      );
    });
    test('blocked when not suspended', () {
      expect(
        checkAccessAction(
            _s(mode: AccountMode.loginEnabled, uid: 'u1'),
            AccessAction.reactivate),
        AccessBlock.notSuspended,
      );
      expect(checkAccessAction(_s(), AccessAction.reactivate),
          AccessBlock.notSuspended);
    });
  });

  group('isPlausibleEmail', () {
    test('accepts normal addresses and trims whitespace', () {
      expect(isPlausibleEmail('a@b.com'), isTrue);
      expect(isPlausibleEmail('  user.name@mail.example.org '), isTrue);
    });
    test('rejects malformed addresses', () {
      for (final bad in ['', 'a', 'a@', '@b.com', 'a@b', 'a b@c.com']) {
        expect(isPlausibleEmail(bad), isFalse, reason: bad);
      }
    });
  });
}
