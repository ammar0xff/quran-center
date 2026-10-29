import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/impl/enrollment_repository_impl.dart';
import 'package:quran_center/features/director/enrollments/enrollment_assignment_screen.dart';

void main() {
  group('EnrollmentAssignmentScreen', () {
    setUpAll(() async {
      await initializeDateFormatting();
    });

    testWidgets('renders assignment form', (tester) async {
      final fake = FakeFirestoreDataSource();
      await fake.setDoc('students/s1', {
        'centerId': 'center-1',
        'fullName': 'أحمد محمد',
        'accountMode': 'none',
        'enrollmentStatus': 'active',
        'assignedTeacherIds': [],
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
      await fake.setDoc('circles/c1', {
        'centerId': 'center-1',
        'name': 'الحلقة الأولى',
        'educationalLevel': 'مبتدئ',
        'maxCapacity': 25,
        'locationOrMode': 'onsite',
        'weeklySchedule': [],
        'sessionDurationMinutes': 60,
        'status': 'active',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            enrollmentRepositoryProvider.overrideWithValue(
              EnrollmentRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: EnrollmentAssignmentScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تعيين الطالب للحلقة'), findsOneWidget);
      expect(find.text('الطالب *'), findsOneWidget);
      expect(find.text('الحلقة *'), findsOneWidget);
    });
  });
}
