import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {
  'stu@x.com': ('pw', 'u-stu'),
  'new@x.com': ('pw', 'u-new'),
  'nolink@x.com': ('pw', 'u-nolink'),
};

int _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset).millisecondsSinceEpoch;
}

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'u-stu', 'student', name: 'بسمة خالد', studentId: 's1');
  await seedUser(s, 'u-new', 'student', name: 'طالب جديد', studentId: 's-new');
  await seedUser(s, 'u-nolink', 'student', name: 'بلا ملف'); // student login with no student profile

  Future<void> student(String id, String name, {String? circle}) => s.setDoc('students/$id', {
        'centerId': 'center-1', 'fullName': name, 'accountMode': 'loginEnabled',
        'authUserId': 'u-$id', 'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-1'],
        'educationalLevel': 'متوسط', if (circle != null) 'currentCircleId': circle,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await student('s1', 'بسمة خالد', circle: 'cA');
  await student('s-new', 'طالب جديد');
  await student('s2', 'زميل');

  Future<void> circle(String id, String name) => s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': name, 'educationalLevel': 'x', 'maxCapacity': 10,
        'locationOrMode': 'onsite', 'weeklySchedule': [], 'sessionDurationMinutes': 60,
        'status': 'active', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر');
  await circle('cB', 'حلقة المغرب');

  Future<void> session(String id, String circleId, int day, String status) =>
      s.setDoc('schedules/$id', {
        'centerId': 'center-1', 'circleId': circleId, 'teacherId': 'tea-1', 'date': _day(day),
        'startTime': '08:00', 'endTime': '09:00', 'locationOrMode': 'onsite', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('past', 'cA', -3, 'completed');
  await session('next', 'cA', 2, 'scheduled');
  await session('cancelled', 'cA', 1, 'cancelled');
  await session('other', 'cB', 1, 'scheduled');

  Future<void> task(String id, String student, String status, int due,
          {int surah = 112, Map<String, dynamic>? verification, Map<String, dynamic>? claim}) =>
      s.setDoc('learning_tasks/$id', {
        'centerId': 'center-1', 'planId': 'plan_${student}_tea-1', 'studentId': student,
        'teacherId': 'tea-1', 'taskType': 'recentRevision', 'surah': surah, 'startAyah': 1,
        'endAyah': 4, 'assignedDate': _day(-5), 'dueDate': _day(due),
        'teacherInstructions': 'كرّر الآيات', 'status': status,
        if (claim != null) 'selfReportedPractice': claim,
        if (verification != null) 'teacherVerification': verification,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await task('t-late', 's1', 'inProgress', -1, surah: 113);
  await task('t-new', 's1', 'upcoming', 5, surah: 114);
  await task('t-redo', 's1', 'needsReview', 6, surah: 1,
      verification: {'verifiedAt': _day(-1), 'verifiedBy': 'tea-1', 'result': 'needs_improvement', 'feedback': 'راجع المخارج'});
  await task('t-done', 's1', 'completed', -4, surah: 112,
      verification: {'verifiedAt': _day(-4), 'verifiedBy': 'tea-1', 'result': 'passed'});
  await task('t-reported', 's1', 'practiceReported', 7, surah: 2, claim: {'reportedAt': _day(-1)});
  await task('t-peer', 's2', 'upcoming', 3);

  await s.setDoc('memorization_records/m1', {
    'centerId': 'center-1', 'studentId': 's1', 'teacherId': 'tea-1', 'sessionId': 'past',
    'assessmentType': 'newMemorization', 'schemaVersion': 1, 'surah': 1, 'startAyah': 1,
    'endAyah': 7, 'criteriaScores': {'accuracy': 2.0}, 'mistakesCount': 9, 'requiresFollowUp': true,
    'studentVisibleFeedback': 'أحسنتِ، واصلي', 'strengths': 'صوت جميل',
    'recommendedNextAssignment': 'سورة البقرة',
    'assessedAt': _day(-3), 'createdAt': _day(-3), 'updatedAt': _day(-3),
  });
  await s.setDoc('memorization_records/m-peer', {
    'centerId': 'center-1', 'studentId': 's2', 'teacherId': 'tea-1', 'sessionId': 'past',
    'assessmentType': 'recentRevision', 'schemaVersion': 1, 'surah': 2, 'startAyah': 1,
    'endAyah': 3, 'criteriaScores': {}, 'mistakesCount': 0, 'requiresFollowUp': false,
    'studentVisibleFeedback': 'ملاحظة لزميل',
    'assessedAt': _day(-3), 'createdAt': _day(-3), 'updatedAt': _day(-3),
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, {String as = 'stu@x.com', String? path}) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn(as, 'pw');
    if (path != null) await app.go(path);
    return app;
  }

  testWidgets('a student with no linked profile is blocked, not shown an empty app', (tester) async {
    await open(tester, as: 'nolink@x.com');
    expect(find.text('بيانات الحساب غير مكتملة'), findsOneWidget);
    expect(find.text('أهلاً بك، بلا ملف'), findsNothing);
  });

  testWidgets('a student cannot open teacher or director screens by URL', (tester) async {
    final app = await open(tester);
    await app.go('/teacher/home');
    expect(find.text('بسمة خالد'), findsOneWidget);
    await app.go('/director/students');
    expect(find.text('إدارة الطلاب'), findsNothing);
  });

  group('home', () {
    testWidgets('shows the most urgent task, the next class, honest counts and feedback', (tester) async {
      await open(tester);
      expect(find.text('بسمة خالد'), findsOneWidget);
      // The overdue task comes first.
      expect(find.textContaining('مراجعة قريبة • الفلق: 1–4'), findsOneWidget);
      expect(find.textContaining('متأخرة'), findsWidgets);
      // Next class skips the cancelled and the other circle's session.
      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);
      // 1 teacher-verified; 4 open (late, new, redo, reported).
      Finder countOf(String title) => find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(Column)).first,
          matching: find.byType(Text));
      expect(tester.widgetList<Text>(countOf('مهام معتمدة من المعلم')).any((t) => t.data == '1'), isTrue);
      expect(tester.widgetList<Text>(countOf('مهام مفتوحة')).any((t) => t.data == '4'), isTrue);
      await tester.scrollUntilVisible(find.textContaining('أحسنتِ، واصلي'), 300);
      expect(find.textContaining('أحسنتِ، واصلي'), findsOneWidget);
    });

    testWidgets('a brand-new student sees plain empty states, not zeros dressed up', (tester) async {
      await open(tester, as: 'new@x.com');
      expect(find.text('لا توجد مهام بعد. سيسندها إليك معلمك.'), findsOneWidget);
      expect(find.text('لم تُسجَّل في حلقة بعد. تواصل مع إدارة الدار.'), findsOneWidget);
      expect(find.text('لا توجد ملاحظات بعد.'), findsOneWidget);
    });
  });

  group('tasks', () {
    testWidgets('open tasks by default; only mine; filters switch the view', (tester) async {
      await open(tester, path: '/student/tasks');
      // 1 of 5 tasks is teacher-verified; the progress card is not a task card.
      expect(find.text('اعتمد المعلم 1 من 5 مهمة'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(5)); // progress card + 4 open tasks
      await tester.tap(find.widgetWithText(ChoiceChip, 'المكتملة'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ChoiceChip, 'تحتاج إعادة'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ChoiceChip, 'الكل'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(6)); // never the classmate's task
    });

    testWidgets('starting a task, then reporting practice, records a claim and does not complete it',
        (tester) async {
      final app = await open(tester, path: '/student/tasks/t-new');
      expect(find.text('كرّر الآيات'), findsOneWidget);
      await tester.tap(find.text('بدأتُ العمل'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('learning_tasks/t-new'))!['status'], 'inProgress');

      await tester.tap(find.text('أتممتُ التدريب'));
      await tester.pumpAndSettle();
      expect(find.textContaining('يبقى على معلمك أن يسمع منك ويعتمدها'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'ملاحظة عن تدريبك (اختياري)'), 'عشر مرات');
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل'));
      await tester.pumpAndSettle();

      final t = (await app.store.getDoc('learning_tasks/t-new'))!;
      expect(t['status'], 'practiceReported');
      expect((t['selfReportedPractice'] as Map)['reflection'], 'عشر مرات');
      expect(t.containsKey('teacherVerification'), isFalse);
      expect(find.textContaining('بانتظار أن يسمع منك معلمك'), findsOneWidget);
      expect(find.text('إرسال للمراجعة'), findsOneWidget);
    });

    testWidgets('a reported task can be sent for review', (tester) async {
      final app = await open(tester, path: '/student/tasks/t-reported');
      await tester.tap(find.text('إرسال للمراجعة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('learning_tasks/t-reported'))!['status'], 'submittedForReview');
      expect(find.text('إرسال للمراجعة'), findsNothing);
    });

    testWidgets('a returned task shows the teacher\'s note and can be retried', (tester) async {
      final app = await open(tester, path: '/student/tasks/t-redo');
      expect(find.text('طلب المعلم إعادة المحاولة'), findsOneWidget);
      expect(find.text('راجع المخارج'), findsOneWidget);
      await tester.tap(find.text('أعيد المحاولة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('learning_tasks/t-redo'))!['status'], 'inProgress');
    });

    testWidgets('a verified task shows the teacher\'s approval and offers no actions', (tester) async {
      await open(tester, path: '/student/tasks/t-done');
      expect(find.textContaining('اعتمد المعلم إنجازك'), findsOneWidget);
      expect(find.text('أتممتُ التدريب'), findsNothing);
      expect(find.text('بدأتُ العمل'), findsNothing);
    });

    testWidgets('a classmate\'s task is just "not found"', (tester) async {
      await open(tester, path: '/student/tasks/t-peer');
      expect(find.text('المهمة غير موجودة'), findsOneWidget);
    });
  });

  testWidgets('schedule lists upcoming sessions of my circle only, marking cancelled ones',
      (tester) async {
    await open(tester, path: '/student/schedule');
    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('ملغاة'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2)); // next + cancelled; not the past or other circle's
  });

  testWidgets('feedback shows only what the teacher wrote for the student', (tester) async {
    await open(tester, path: '/student/feedback');
    expect(find.text('أحسنتِ، واصلي'), findsOneWidget);
    expect(find.textContaining('نقاط القوة: صوت جميل'), findsOneWidget);
    expect(find.textContaining('الواجب المقترح: سورة البقرة'), findsOneWidget);
    // No scores, no mistake counts, nothing about a classmate.
    expect(find.textContaining('9'), findsNothing);
    expect(find.text('ملاحظة لزميل'), findsNothing);
  });

  testWidgets('profile shows my details and signs out', (tester) async {
    await open(tester, path: '/student/profile');
    expect(find.text('بسمة خالد'), findsOneWidget);
    expect(find.text('حلقة الفجر'), findsOneWidget);
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
  });
}
