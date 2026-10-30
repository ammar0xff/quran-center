import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director', name: 'مديرة الدار');
  Future<void> student(String id, String name, String center, {String? notes}) =>
      s.setDoc('students/$id', {
        'centerId': center,
        'fullName': name,
        'accountMode': 'none',
        'enrollmentStatus': 'active',
        'assignedTeacherIds': <String>[],
        'educationalLevel': 'مبتدئ',
        if (notes != null) 'adminNotes': notes,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });
  await student('s1', 'أحمد علي', 'center-1', notes: 'يحتاج متابعة');
  await student('s2', 'طالب مركز آخر', 'center-2');
  await student('s3', 'طالب آخر', 'center-1');
  await student('s5', 'بدون سجلات', 'center-1');

  await s.setDoc('circles/cA', {
    'centerId': 'center-1', 'name': 'حلقة الفجر', 'educationalLevel': 'x',
    'assignedTeacherId': 't1', 'maxCapacity': 10, 'locationOrMode': 'onsite',
    'weeklySchedule': [], 'sessionDurationMinutes': 60, 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  await s.setDoc('circles/cB', {
    'centerId': 'center-1', 'name': 'حلقة المغرب', 'educationalLevel': 'x',
    'maxCapacity': 10, 'locationOrMode': 'onsite',
    'weeklySchedule': [], 'sessionDurationMinutes': 60, 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  await s.setDoc('teachers/t1', {
    'centerId': 'center-1', 'userId': 't1', 'fullName': 'المعلمة فاطمة',
    'status': 'active', 'assignedCircleIds': [],
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  // History: moved from cB to cA.
  await s.setDoc('enrollments/e1', {
    'centerId': 'center-1', 'studentId': 's1', 'circleId': 'cB',
    'startDate': 1700000000000, 'endDate': 1701000000000,
    'status': 'transferred', 'changeReason': 'يناسبه الوقت',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  await s.setDoc('enrollments/e2', {
    'centerId': 'center-1', 'studentId': 's1', 'circleId': 'cA', 'teacherId': 't1',
    'startDate': 1701000000000, 'status': 'active',
    'createdAt': 1701000000000, 'updatedAt': 1701000000000,
  });
  Future<void> att(String id, String student, String status) =>
      s.setDoc('attendance/$id', {
        'centerId': 'center-1', 'sessionId': 'x', 'studentId': student,
        'status': status, 'recordedBy': 't1',
        'createdAt': 1701000000000, 'updatedAt': 1701000000000,
      });
  await att('x_s1', 's1', 'present');
  await att('y_s1', 's1', 'absent');
  await att('z_s1', 's1', 'absent');
  await att('x_s3', 's3', 'present'); // someone else's: must not be counted for s1
  await s.setDoc('audit_logs/a1', {
    'centerId': 'center-1', 'actorUserId': 'dir-1', 'actorRole': 'director',
    'action': 'assign_student', 'entityType': 'student', 'entityId': 's1',
    'reason': 'توزيع', 'createdAt': 1701000000000,
  });
  await s.setDoc('audit_logs/a2', {
    'centerId': 'center-1', 'actorUserId': 'dir-1', 'action': 'archive_student',
    'entityType': 'student', 'entityId': 's3', 'createdAt': 1701000000000,
  });
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, String id) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/students/$id');
    return app;
  }

  testWidgets('overview shows the real current circle, teacher, attendance and notes',
      (tester) async {
    await open(tester, 's1');
    expect(find.text('أحمد علي'), findsWidgets);
    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('المعلمة فاطمة'), findsOneWidget);
    expect(find.text('يحتاج متابعة'), findsOneWidget);
    // 1 present / (1 present + 2 absent) = 33.3%, over s1's own 3 records only.
    expect(find.textContaining('33.3%'), findsOneWidget);
    expect(find.textContaining('3 سجل'), findsOneWidget);
  });

  testWidgets('a student with nothing recorded says so, with no invented numbers',
      (tester) async {
    await open(tester, 's5');
    expect(find.text('غير مسجّل في حلقة'), findsOneWidget);
    expect(find.text('لا يوجد معلم'), findsOneWidget);
    expect(find.text('لا توجد سجلات حضور بعد'), findsOneWidget);
  });

  testWidgets('another center\'s student, or a missing id, reads as not found',
      (tester) async {
    final app = await open(tester, 's2');
    expect(find.text('الطالب غير موجود'), findsOneWidget);
    expect(find.text('طالب مركز آخر'), findsNothing);

    await app.go('/director/students/nope');
    expect(find.text('الطالب غير موجود'), findsOneWidget);
  });

  testWidgets('enrolment tab lists the history, newest first, transfer reason included',
      (tester) async {
    await open(tester, 's1');
    await _tab(tester, 'التسجيل');
    expect(find.textContaining('حالي'), findsOneWidget);
    expect(find.textContaining('منقول'), findsOneWidget);
    expect(find.textContaining('السبب: يناسبه الوقت'), findsOneWidget);
    final newest = tester.getTopLeft(find.text('حلقة الفجر')).dy;
    final oldest = tester.getTopLeft(find.text('حلقة المغرب')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('attendance tab shows this student\'s records and summary', (tester) async {
    await open(tester, 's1');
    await _tab(tester, 'الحضور');
    expect(find.text('نسبة الحضور: 33.3%'), findsOneWidget);
    expect(find.textContaining('حاضر 1 • متأخر 0 • غائب 2'), findsOneWidget);
  });

  testWidgets('audit tab shows only this student\'s entries, with the actor\'s name',
      (tester) async {
    await open(tester, 's1');
    await _tab(tester, 'سجل التدقيق');
    expect(find.text('تعيين لحلقة'), findsOneWidget);
    expect(find.textContaining('بواسطة: مديرة الدار'), findsOneWidget);
    expect(find.textContaining('السبب: توزيع'), findsOneWidget);
    expect(find.text('أرشفة الطالب'), findsNothing); // belongs to s3
  });

  group('edit', () {
    testWidgets('saves changed fields, audits them, and the profile refreshes',
        (tester) async {
      final app = await open(tester, 's1');
      await tester.tap(find.byTooltip('تعديل البيانات'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'المستوى التعليمي *'), 'متقدم');
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect((await app.store.getDoc('students/s1'))!['educationalLevel'], 'متقدم');
      final audits = (await app.store.query('audit_logs', where: []))
          .where((a) => a['action'] == 'update_student');
      expect(audits.single['actorUserId'], 'dir-1');
      expect((audits.single['previousValue'] as Map)['educationalLevel'], 'مبتدئ');

      expect(find.text('تم حفظ التعديلات'), findsOneWidget);
      expect(find.text('المستوى: متقدم'), findsOneWidget); // back on a refreshed profile
    });

    testWidgets('a blank name is refused and nothing is written', (tester) async {
      final app = await open(tester, 's1');
      await tester.tap(find.byTooltip('تعديل البيانات'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('الاسم مطلوب'), findsOneWidget);
      expect((await app.store.getDoc('students/s1'))!['fullName'], 'أحمد علي');
    });

    testWidgets('saving without changes says so and writes no audit', (tester) async {
      final app = await open(tester, 's1');
      await tester.tap(find.byTooltip('تعديل البيانات'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد تعديلات لحفظها'), findsOneWidget);
      expect(
          (await app.store.query('audit_logs', where: []))
              .where((a) => a['action'] == 'update_student'),
          isEmpty);
    });

    testWidgets('another center\'s student cannot be edited', (tester) async {
      final app = await open(tester, 's1');
      await app.go('/director/students/s2/edit');
      expect(find.text('الطالب غير موجود'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'حفظ'), findsNothing);
    });
  });
}
