import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student model', () {
    final json = {
      'centerId': 'center-1',
      'fullName': 'سارة أحمد',
      'preferredName': 'سارة',
      'dateOfBirth': 1700000000000,
      'contactInfo': {'phone': '+966501234567'},
      'profileImageUrl': 'https://example.com/img.png',
      'enrollmentStatus': 'active',
      'accountMode': 'none',
      'authUserId': null,
      'educationalLevel': 'مبتدئ',
      'accessibilityPreferences': null,
      'adminNotes': null,
      'createdBy': 'director-1',
      'updatedBy': 'director-1',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final student = Student.fromJson('student-1', json);
      expect(student.studentId, 'student-1');
      expect(student.fullName, 'سارة أحمد');
      expect(student.displayName, 'سارة'); // preferred name
      expect(student.enrollmentStatus, EnrollmentStatus.active);
      expect(student.accountMode, AccountMode.none);
      expect(student.authUserId, isNull);
      expect(student.hasLogin, isFalse);
      expect(student.educationalLevel, 'مبتدئ');

      final back = student.toJson();
      expect(back['centerId'], 'center-1');
      expect(back['fullName'], 'سارة أحمد');
      expect(back['accountMode'], 'none');
      expect(back['authUserId'], isNull);
    });

    test('hasLogin true when accountMode loginEnabled and authUserId set', () {
      final withLogin = Student.fromJson('s', {...json, 'accountMode': 'loginEnabled', 'authUserId': 'uid-1'});
      expect(withLogin.hasLogin, isTrue);

      final noUserId = Student.fromJson('s', {...json, 'accountMode': 'loginEnabled', 'authUserId': null});
      expect(noUserId.hasLogin, isFalse);
    });

    test('displayName falls back to fullName when no preferredName', () {
      final noPref = Student.fromJson('s', {...json, 'preferredName': null});
      expect(noPref.displayName, 'سارة أحمد');
    });

    test('copyWith preserves immutable fields', () {
      final student = Student.fromJson('student-1', json);
      final updated = student.copyWith(educationalLevel: 'متوسط');
      expect(updated.studentId, 'student-1');
      expect(updated.educationalLevel, 'متوسط');
      expect(updated.fullName, 'سارة أحمد'); // unchanged
    });
  });
}
