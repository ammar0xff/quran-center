import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'tea@x.com': ('pw', 'tea-1')};

int _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset).millisecondsSinceEpoch;
}

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  await s.setDoc('circles/cA', {
    'centerId': 'center-1', 'name': 'حلقة الفجر', 'educationalLevel': 'x', 'maxCapacity': 10,
    'assignedTeacherId': 'tea-1', 'locationOrMode': 'onsite', 'weeklySchedule': [],
    'sessionDurationMinutes': 60, 'status': 'active',
    'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  for (final (id, name, teacher) in [
    ('s1', 'بسمة خالد', 'tea-1'),
    ('s2', 'أحمد علي', 'tea-1'),
    ('s9', 'طالب معلم آخر', 'tea-2'),
  ]) {
    await s.setDoc('students/$id', {
      'centerId': 'center-1', 'fullName': name, 'accountMode': 'none',
      'enrollmentStatus': 'active', 'assignedTeacherIds': [teacher],
      'educationalLevel': 'متوسط', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'center-1', 'studentId': id, 'circleId': 'cA', 'teacherId': teacher,
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  Future<void> task(String id, String student, String status,
          {int due = 5, Map<String, dynamic>? claim, String teacher = 'tea-1', int surah = 112}) =>
      s.setDoc('learning_tasks/$id', {
        'centerId': 'center-1', 'planId': 'plan_${student}_$teacher', 'studentId': student,
        'teacherId': teacher, 'taskType': 'recentRevision', 'surah': surah, 'startAyah': 1,
        'endAyah': 4, 'assignedDate': _day(-3), 'dueDate': _day(due),
        'teacherInstructions': 'راجع جيدًا', 'status': status,
        if (claim != null) 'selfReportedPractice': claim,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await task('t-reported', 's1', 'practiceReported', claim: {'reportedAt': _day(-1)});
  await task('t-late', 's1', 'inProgress', due: -2, surah: 113);
  await task('t-done', 's1', 'completed', surah: 114);
  await task('t-other', 's9', 'practiceReported', teacher: 'tea-2');

  await s.setDoc('memorization_records/m1', {
    'centerId': 'center-1', 'studentId': 's1', 'teacherId': 'tea-1', 'sessionId': 'x',
    'assessmentType': 'newMemorization', 'schemaVersion': 1, 'surah': 1, 'startAyah': 1,
    'endAyah': 7, 'criteriaScores': {}, 'mistakesCount': 0, 'grade': 'veryGood',
    'requiresFollowUp': true, 'studentVisibleFeedback': 'أحسنتِ',
    'assessedAt': _day(-2), 'createdAt': _day(-2), 'updatedAt': _day(-2),
  });
  await s.setDoc('memorization_records/m-visit', {
    'centerId': 'center-1', 'studentId': 's1', 'teacherId': 'tea-9', 'sessionId': 'y',
    'assessmentType': 'recentRevision', 'schemaVersion': 1, 'surah': 112, 'startAyah': 1,
    'endAyah': 4, 'criteriaScores': {}, 'mistakesCount': 0, 'grade': 'acceptable',
    'requiresFollowUp': false, 'assessedAt': _day(-1), 'createdAt': _day(-1), 'updatedAt': _day(-1),
  });
  await s.setDoc('private_teacher_notes/m1', {
    'centerId': 'center-1', 'studentId': 's1', 'teacherId': 'tea-1', 'note': 'تحتاج دعمًا',
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

  Future<AppHarness> open(WidgetTester tester, String path) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('tea@x.com', 'pw');
    await app.go(path);
    return app;
  }

  testWidgets('home counts reports awaiting verification and overdue tasks', (tester) async {
    await open(tester, '/teacher/home');
    Finder countOf(String title) => find.descendant(
        of: find.widgetWithText(ListTile, title), matching: find.text('1'));
    expect(countOf('مهام بانتظار تحققك'), findsOneWidget); // t-other belongs to tea-2
    expect(countOf('مهام متأخرة'), findsOneWidget);
  });

  testWidgets('the student list is only my students, with open task counts', (tester) async {
    await open(tester, '/teacher/students');
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('طالب معلم آخر'), findsNothing);
    expect(find.textContaining('2 مهام مفتوحة'), findsOneWidget); // reported + overdue, not the done one

    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.pumpAndSettle();
    expect(find.text('بسمة خالد'), findsNothing);
  });

  testWidgets('the profile shows the level from every wird, also those a visiting teacher heard',
      (tester) async {
    await open(tester, '/teacher/students/s1');
    // (4 + 2) / 2 = 3.0 -> جيد
    expect(find.textContaining('المستوى: جيد (3.0 من 5)'), findsOneWidget);
    expect(find.textContaining('من آخر 2 أوراد'), findsOneWidget);
    expect(find.textContaining('سمعتها معلمة أخرى'), findsOneWidget);
  });

  testWidgets('the student list shows each student\'s level, or says there is none',
      (tester) async {
    await open(tester, '/teacher/students');
    expect(find.textContaining('المستوى: جيد (3.0 من 5)'), findsOneWidget);
    expect(find.textContaining('لا يوجد مستوى بعد'), findsOneWidget); // s2 has no graded wird
  });

  testWidgets('another teacher\'s student is not reachable by URL', (tester) async {
    await open(tester, '/teacher/students/s9');
    expect(find.text('الطالب غير موجود ضمن طلابك'), findsOneWidget);
    expect(find.text('طالب معلم آخر'), findsNothing);
  });

  group('profile', () {
    testWidgets('assessments show criteria, student feedback, and the private note marked as private',
        (tester) async {
      await open(tester, '/teacher/students/s1');
      expect(find.textContaining('ورد الحفظ • الفاتحة: 1–7'), findsOneWidget);
      expect(find.text('جيد جدًا'), findsOneWidget);
      expect(find.textContaining('للطالب: أحسنتِ'), findsOneWidget);
      expect(find.textContaining('ملاحظة خاصة (لا يراها الطالب): تحتاج دعمًا'), findsOneWidget);
      expect(find.textContaining('يحتاج متابعة'), findsOneWidget);
    });

    testWidgets('tasks distinguish a student\'s claim from teacher verification', (tester) async {
      await open(tester, '/teacher/students/s1');
      await _tab(tester, 'المهام');
      expect(find.textContaining('بلاغ الطالب بالتدريب (غير مُتحقَّق منه)'), findsOneWidget);
      expect(find.textContaining('متأخرة •'), findsOneWidget);
      // The completed task has no actions; open ones do.
      expect(find.text('تحقق'), findsNWidgets(2));
    });

    testWidgets('verifying as passed completes the task with attribution', (tester) async {
      final app = await open(tester, '/teacher/students/s1');
      await _tab(tester, 'المهام');
      await tester.tap(find.text('تحقق').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'ملاحظة (اختياري)'), 'ممتاز');
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();

      final done = (await app.store.query('learning_tasks', where: []))
          .where((t) => t['teacherVerification'] != null)
          .single;
      expect(done['status'], 'completed');
      expect((done['teacherVerification'] as Map)['verifiedBy'], 'tea-1');
      expect(find.text('تم حفظ التحقق'), findsOneWidget);
    });

    testWidgets('"needs improvement" does not complete the task', (tester) async {
      final app = await open(tester, '/teacher/students/s1');
      await _tab(tester, 'المهام');
      await tester.tap(find.text('تحقق').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحتاج إعادة').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();
      final statuses = (await app.store.query('learning_tasks', where: []))
          .where((t) => t['studentId'] == 's1')
          .map((t) => t['status'])
          .toList();
      expect(statuses, contains('needsReview'));
      expect(statuses.where((s) => s == 'completed'), hasLength(1)); // only the pre-existing one
    });

    testWidgets('cancelling requires a reason', (tester) async {
      final app = await open(tester, '/teacher/students/s1');
      await _tab(tester, 'المهام');
      await tester.tap(find.text('إلغاء المهمة').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'إلغاء المهمة'));
      await tester.pumpAndSettle();
      expect(find.text('سبب الإلغاء مطلوب.'), findsOneWidget);
      expect((await app.store.query('learning_tasks', where: [])).where((t) => t['status'] == 'cancelled'),
          isEmpty);

      await tester.tap(find.text('إلغاء المهمة').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'سبب الإلغاء *'), 'تغيّرت الخطة');
      await tester.tap(find.widgetWithText(FilledButton, 'إلغاء المهمة'));
      await tester.pumpAndSettle();
      final cancelled = (await app.store.query('learning_tasks', where: []))
          .where((t) => t['status'] == 'cancelled');
      expect(cancelled, hasLength(1));
      expect((cancelled.single['completionMetadata'] as Map)['reason'], 'تغيّرت الخطة');
      expect(find.text('تم إلغاء المهمة'), findsOneWidget);
    });

    testWidgets('attendance tab explains there is nothing yet', (tester) async {
      await open(tester, '/teacher/students/s1');
      await _tab(tester, 'الحضور');
      expect(find.textContaining('لا توجد سجلات حضور سجّلتَها'), findsOneWidget);
    });
  });

  group('new task', () {
    Future<AppHarness> openForm(WidgetTester tester) => open(tester, '/teacher/students/s2/tasks/new');

    Future<void> pickSurah(WidgetTester tester, String name) async {
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'السورة *'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.textContaining(name), find.byType(Scrollable).last, const Offset(0, -300));
      await tester.tap(find.textContaining(name));
      await tester.pumpAndSettle();
    }

    testWidgets('validation errors are shown and nothing is written', (tester) async {
      final app = await openForm(tester);
      await tester.tap(find.text('إسناد المهمة'));
      await tester.pumpAndSettle();
      expect(find.text('اختر السورة'), findsOneWidget);

      await pickSurah(tester, 'الإخلاص');
      await tester.enterText(find.widgetWithText(TextField, 'من آية *'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'إلى آية *'), '9');
      await tester.tap(find.text('إسناد المهمة'));
      await tester.pumpAndSettle();
      expect(find.text('آية النهاية بين 1 و 4'), findsOneWidget);
      expect((await app.store.query('learning_tasks', where: [])).where((t) => t['studentId'] == 's2'),
          isEmpty);
    });

    testWidgets('assigns an upcoming task and returns to the profile', (tester) async {
      final app = await open(tester, '/teacher/students/s2');
      await tester.tap(find.text('مهمة جديدة'));
      await tester.pumpAndSettle();
      await pickSurah(tester, 'الإخلاص');
      await tester.enterText(find.widgetWithText(TextField, 'من آية *'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'إلى آية *'), '4');
      await tester.enterText(find.widgetWithText(TextField, 'تعليمات للطالب (اختياري)'), 'كرّر عشر مرات');
      await tester.tap(find.text('إسناد المهمة'));
      await tester.pumpAndSettle();

      final created = (await app.store.query('learning_tasks', where: []))
          .singleWhere((t) => t['studentId'] == 's2');
      expect(created['status'], 'upcoming');
      expect(created['teacherId'], 'tea-1');
      expect(created['planId'], 'plan_s2_tea-1');
      expect(created['surah'], 112);
      expect(await app.store.getDoc('learning_plans/plan_s2_tea-1'), isNotNull);

      expect(find.text('تم إسناد المهمة'), findsOneWidget);
      expect(find.text('ملف الطالب'), findsOneWidget);
      await _tab(tester, 'المهام');
      expect(find.textContaining('كرّر عشر مرات'), findsOneWidget);
    });

    testWidgets('a student of another teacher cannot be given a task', (tester) async {
      final app = await open(tester, '/teacher/students/s9/tasks/new');
      await pickSurah(tester, 'الإخلاص');
      await tester.enterText(find.widgetWithText(TextField, 'من آية *'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'إلى آية *'), '4');
      await tester.tap(find.text('إسناد المهمة'));
      await tester.pumpAndSettle();
      expect(find.text('هذا الطالب ليس ضمن طلابك الحاليين.'), findsOneWidget);
      expect((await app.store.query('learning_tasks', where: [])).where((t) => t['studentId'] == 's9' && t['teacherId'] == 'tea-1'),
          isEmpty);
    });
  });
}
