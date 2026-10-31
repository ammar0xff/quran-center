import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/demo/demo_controller.dart';
import 'package:quran_center/data/datasources/demo_center_seed.dart';
import 'package:quran_center/data/models/enums.dart';

void main() {
  group('Demo Mode & 3-in-1 Role Switcher Tests', () {
    test('default state is not demo mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isDemoModeProvider), isFalse);
      expect(container.read(demoActiveRoleProvider), UserRole.director);
    });

    test('entering demo mode updates session to Demo Director automatically', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Turn on demo mode
      container.read(isDemoModeProvider.notifier).state = true;
      container.read(demoActiveRoleProvider.notifier).state = UserRole.director;

      final session = container.read(currentSessionProvider);
      expect(session.kind, SessionKind.director);
      expect(session.profile?.uid, DemoCenterSeed.directorUser.uid);
      expect(session.profile?.fullName, contains('أم عبدالله'));
    });

    test('switching active demo role updates session to Teacher and Student reactively', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(isDemoModeProvider.notifier).state = true;

      // Switch to Teacher
      container.read(demoActiveRoleProvider.notifier).state = UserRole.teacher;
      var session = container.read(currentSessionProvider);
      expect(session.kind, SessionKind.teacher);
      expect(session.profile?.uid, DemoCenterSeed.teacherUser.uid);
      expect(session.profile?.fullName, contains('فاطمة الزهراء'));

      // Switch to Student
      container.read(demoActiveRoleProvider.notifier).state = UserRole.student;
      session = container.read(currentSessionProvider);
      expect(session.kind, SessionKind.student);
      expect(session.profile?.uid, DemoCenterSeed.studentUser.uid);
      expect(session.profile?.fullName, contains('بسمة خالد'));

      // Switch back to Director
      container.read(demoActiveRoleProvider.notifier).state = UserRole.director;
      session = container.read(currentSessionProvider);
      expect(session.kind, SessionKind.director);
    });

    test('seeded demo data source contains valid demo center documents', () async {
      final ds = DemoCenterSeed.createSeededDataSource();

      final centerDoc = await ds.getDoc('centers/demo-center');
      expect(centerDoc, isNotNull);
      expect(centerDoc?['name'], contains('دار النور'));

      final circleDoc = await ds.getDoc('circles/circle-fajr');
      expect(circleDoc, isNotNull);
      expect(circleDoc?['name'], contains('حلقة الفجر'));

      final studentDoc = await ds.getDoc('students/stu-1');
      expect(studentDoc, isNotNull);
      expect(studentDoc?['fullName'], 'بسمة خالد');
    });
  });
}
