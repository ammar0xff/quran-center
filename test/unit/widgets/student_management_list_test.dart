import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/impl/student_repository_impl.dart';
import 'package:quran_center/features/director/students/student_management_list_screen.dart';

void main() {
  group('StudentManagementListScreen', () {
    testWidgets('renders students list and empty state', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentRepositoryProvider.overrideWithValue(
              StudentRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: StudentManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إدارة الطلاب'), findsOneWidget);
      expect(find.text('أحمد محمد'), findsOneWidget);
      expect(find.text('منتظم'), findsOneWidget);
    });

    testWidgets('shows empty state when no students', (tester) async {
      final fake = FakeFirestoreDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentRepositoryProvider.overrideWithValue(
              StudentRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: StudentManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا يوجد طلاب'), findsOneWidget);
    });
  });
}
