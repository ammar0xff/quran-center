import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/attendance/attendance_administration_screen.dart';

Future<void> _seed(FakeFirestoreDataSource fake) async {
  Map<String, dynamic> student(String name) => {
        'centerId': 'center-1',
        'fullName': name,
        'accountMode': 'none',
        'enrollmentStatus': 'active',
        'assignedTeacherIds': [],
        'educationalLevel': 'مبتدئ',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      };
  Map<String, dynamic> att(String student, String status) => {
        'centerId': 'center-1',
        'sessionId': 'sess1',
        'studentId': student,
        'status': status,
        'recordedBy': 'teacher1',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      };
  await fake.setDoc('students/p', student('طالب حاضر'));
  await fake.setDoc('students/a', student('طالب غائب'));
  await fake.setDoc('attendance/sess1_p', att('p', 'present'));
  await fake.setDoc('attendance/sess1_a', att('a', 'absent'));
}

Widget _app(FakeFirestoreDataSource fake) => ProviderScope(
      overrides: [
        firestoreDataSourceProvider.overrideWithValue(fake),
        actorProvider.overrideWithValue(const Actor('director-9', 'director')),
      ],
      child: const MaterialApp(home: AttendanceAdministrationScreen()),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets('shows summary with the documented rate', (tester) async {
    final fake = FakeFirestoreDataSource();
    await _seed(fake);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.text('طالب حاضر'), findsOneWidget);
    expect(find.text('طالب غائب'), findsOneWidget);
    // 1 present, 1 absent -> 50.0%
    expect(find.text('نسبة الحضور: 50.0%'), findsOneWidget);
  });

  testWidgets('status filter narrows the list', (tester) async {
    final fake = FakeFirestoreDataSource();
    await _seed(fake);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'غائب'));
    await tester.pumpAndSettle();

    expect(find.text('طالب غائب'), findsOneWidget);
    expect(find.text('طالب حاضر'), findsNothing);
  });

  testWidgets('empty state when there are no records', (tester) async {
    await tester.pumpWidget(_app(FakeFirestoreDataSource()));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد سجلات حضور بعد'), findsOneWidget);
  });

  testWidgets('correction requires a reason, then saves and audits',
      (tester) async {
    final fake = FakeFirestoreDataSource();
    await _seed(fake);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'غائب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تصحيح'));
    await tester.pumpAndSettle();

    // Pick a different status but leave the reason blank.
    await tester.tap(find.byType(DropdownButtonFormField<AttendanceStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معذور').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ التصحيح'));
    await tester.pumpAndSettle();

    expect(find.text('سبب التصحيح مطلوب'), findsOneWidget);
    expect((await fake.getDoc('attendance/sess1_a'))!['status'], 'absent');

    // Provide the reason and save.
    await tester.enterText(find.byType(TextField), 'شهادة طبية');
    await tester.tap(find.text('حفظ التصحيح'));
    await tester.pumpAndSettle();

    final stored = (await fake.getDoc('attendance/sess1_a'))!;
    expect(stored['status'], 'excused');
    expect((stored['correctionMetadata'] as Map)['originalStatus'], 'absent');

    final audit = await fake.query('audit_logs', where: []);
    expect(audit, hasLength(1));
    expect(audit.single['actorUserId'], 'director-9');
    expect(audit.single['reason'], 'شهادة طبية');

    expect(find.text('تم تصحيح الحضور وتسجيل التغيير'), findsOneWidget);
  });
}
