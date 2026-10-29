import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User model', () {
    final json = {
      'centerId': 'center-1',
      'fullName': 'أحمد محمد',
      'role': 'teacher',
      'status': 'active',
      'authProvider': 'password',
      'phone': '+966501234567',
      'profileImageUrl': 'https://example.com/img.png',
      'assignedCenterIds': ['center-1'],
      'lastSignInAt': 1700000000000,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip preserves all fields', () {
      final user = User.fromJson('uid-1', json);
      expect(user.uid, 'uid-1');
      expect(user.centerId, 'center-1');
      expect(user.fullName, 'أحمد محمد');
      expect(user.role, UserRole.teacher);
      expect(user.status, AccountStatus.active);
      expect(user.authProvider, 'password');
      expect(user.phone, '+966501234567');
      expect(user.profileImageUrl, 'https://example.com/img.png');
      expect(user.assignedCenterIds, ['center-1']);
      expect(user.lastSignInAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(user.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));

      final back = user.toJson();
      expect(back['centerId'], 'center-1');
      expect(back['fullName'], 'أحمد محمد');
      expect(back['role'], 'teacher');
      expect(back['status'], 'active');
      expect(back['phone'], '+966501234567');
    });

    test('isActive/isDirector/isTeacher/isStudent derive from role/status', () {
      final activeTeacher = User.fromJson('u', {...json, 'role': 'teacher', 'status': 'active'});
      expect(activeTeacher.isActive, isTrue);
      expect(activeTeacher.isTeacher, isTrue);
      expect(activeTeacher.isDirector, isFalse);
      expect(activeTeacher.isStudent, isFalse);

      final suspended = User.fromJson('u', {...json, 'status': 'suspended'});
      expect(suspended.isActive, isFalse);
    });

    test('copyWith creates a new instance with updated fields', () {
      final user = User.fromJson('u', json);
      final updated = user.copyWith(fullName: 'فاطمة علي', status: AccountStatus.suspended);
      expect(updated.uid, 'u');
      expect(updated.fullName, 'فاطمة علي');
      expect(updated.status, AccountStatus.suspended);
      expect(updated.centerId, 'center-1'); // unchanged
      expect(updated == user, isFalse);
    });

    test('equality compares all fields', () {
      final a = User.fromJson('u', json);
      final bSame = User.fromJson('u', json);
      expect(a == bSame, isTrue);

      final bDiff = User.fromJson('u', {...json, 'fullName': '其他'});
      expect(a == bDiff, isFalse);

      final differentUid = User.fromJson('other-uid', json);
      expect(a == differentUid, isFalse);
    });
  });
}
