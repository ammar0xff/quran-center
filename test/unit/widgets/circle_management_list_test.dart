import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/impl/circle_repository_impl.dart';
import 'package:quran_center/features/director/circles/circle_management_list_screen.dart';

void main() {
  group('CircleManagementListScreen', () {
    testWidgets('renders circles list and empty state', (tester) async {
      final fake = FakeFirestoreDataSource();
      await fake.setDoc('circles/c1', {
        'centerId': 'center-1',
        'name': 'الحلقة الأولى',
        'educationalLevel': 'مبتدئ',
        'maxCapacity': 25,
        'locationOrMode': 'onsite',
        'weeklySchedule': [
          {'dayOfWeek': 1, 'startTime': '08:00', 'endTime': '10:00'}
        ],
        'sessionDurationMinutes': 120,
        'status': 'active',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(
              CircleRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: CircleManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إدارة الحلقات'), findsOneWidget);
      expect(find.text('الحلقة الأولى'), findsOneWidget);
    });

    testWidgets('shows empty state when no circles', (tester) async {
      final fake = FakeFirestoreDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(
              CircleRepositoryImpl(fake),
            ),
          ],
          child: const MaterialApp(
            home: CircleManagementListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا توجد حلقات'), findsOneWidget);
    });
  });
}
