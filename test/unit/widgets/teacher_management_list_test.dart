import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/impl/teacher_repository_impl.dart';
import 'package:quran_center/features/director/teachers/teacher_management_list_screen.dart';

void main() {
  group('TeacherManagementListScreen', () {
    testWidgets('renders teachers list and empty state', (tester) async {
      final fake = FakeFirestoreDataSource();
      await fake.setDoc('teachers/t1', {
        'centerId': 'center-1',
        'fullName': 'فاطمة علي',
        'status': 'active',
        'assignedCircleIds': ['c1'],
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherRepositoryProvider.overrideWithValue(
              TeacherRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: TeacherManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إدارة المعلمين'), findsOneWidget);
      expect(find.text('فاطمة علي'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
    });

    testWidgets('shows empty state when no teachers', (tester) async {
      final fake = FakeFirestoreDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherRepositoryProvider.overrideWithValue(
              TeacherRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: TeacherManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا يوجد معلمون'), findsOneWidget);
    });
  });
}
