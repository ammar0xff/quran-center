import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/impl/circle_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/schedule_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/teacher_repository_impl.dart';
import 'package:quran_center/features/director/schedules/schedule_management_screen.dart';

Future<void> _seed(FakeFirestoreDataSource fake) async {
  final today = DateTime.now();
  final later = today.add(const Duration(days: 30));
  Map<String, dynamic> circle(String name) => {
        'centerId': 'center-1',
        'name': name,
        'educationalLevel': 'مبتدئ',
        'maxCapacity': 20,
        'locationOrMode': 'onsite',
        'weeklySchedule': [],
        'sessionDurationMinutes': 60,
        'status': 'active',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      };
  Map<String, dynamic> session(String circleId, DateTime d) => {
        'centerId': 'center-1',
        'circleId': circleId,
        'teacherId': 't1',
        'date': DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
        'startTime': '08:00',
        'endTime': '09:00',
        'locationOrMode': 'onsite',
        'status': 'scheduled',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      };
  await fake.setDoc('circles/c-today', circle('حلقة اليوم'));
  await fake.setDoc('circles/c-later', circle('حلقة لاحقة'));
  await fake.setDoc('schedules/a', session('c-today', today));
  await fake.setDoc('schedules/b', session('c-later', later));
}

Widget _app(FakeFirestoreDataSource fake) => ProviderScope(
      overrides: [
        centerIdProvider.overrideWithValue('center-1'),
        scheduleRepositoryProvider
            .overrideWithValue(ScheduleRepositoryImpl(fake)),
        circleRepositoryProvider.overrideWithValue(CircleRepositoryImpl(fake)),
        teacherRepositoryProvider
            .overrideWithValue(TeacherRepositoryImpl(fake)),
      ],
      child: const MaterialApp(home: ScheduleManagementScreen()),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('ScheduleManagementScreen', () {
    testWidgets('list view shows every session', (tester) async {
      final fake = FakeFirestoreDataSource();
      await _seed(fake);
      await tester.pumpWidget(_app(fake));
      await tester.pumpAndSettle();

      expect(find.text('حلقة اليوم'), findsOneWidget);
      expect(find.text('حلقة لاحقة'), findsOneWidget);
    });

    testWidgets('daily view narrows to the selected day', (tester) async {
      final fake = FakeFirestoreDataSource();
      await _seed(fake);
      await tester.pumpWidget(_app(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('يومي'));
      await tester.pumpAndSettle();

      expect(find.text('حلقة اليوم'), findsOneWidget);
      expect(find.text('حلقة لاحقة'), findsNothing);
    });

    testWidgets('weekly view excludes sessions 30 days away', (tester) async {
      final fake = FakeFirestoreDataSource();
      await _seed(fake);
      await tester.pumpWidget(_app(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('أسبوعي'));
      await tester.pumpAndSettle();

      expect(find.text('حلقة اليوم'), findsOneWidget);
      expect(find.text('حلقة لاحقة'), findsNothing);
    });

    testWidgets('empty state offers to create a session', (tester) async {
      await tester.pumpWidget(_app(FakeFirestoreDataSource()));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد جلسات'), findsOneWidget);
    });
  });

  group('weekStart', () {
    test('returns the Saturday on or before the date', () {
      // 2026-11-04 is a Wednesday -> week starts Saturday 2026-10-31.
      expect(weekStart(DateTime(2026, 11, 4)), DateTime(2026, 10, 31));
      // A Saturday maps to itself.
      expect(weekStart(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
    });
  });
}
