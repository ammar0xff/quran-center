import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {'dir@x.com': ('pw', 'dir-1')};

int _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset).millisecondsSinceEpoch;
}

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director');
  Future<void> student(String id, String name, String circle, {String center = 'center-1'}) =>
      s.setDoc('students/$id', {
        'centerId': center, 'fullName': name, 'accountMode': 'none', 'enrollmentStatus': 'active',
        'assignedTeacherIds': [], 'currentCircleId': circle, 'educationalLevel': 'x',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await student('s1', 'أحمد علي', 'cA');
  await student('s2', 'بسمة خالد', 'cA');
  await student('s3', 'جميلة', 'cB');
  await student('sx', 'طالب مركز آخر', 'cX', center: 'center-2');
  Future<void> circle(String id, String name, String teacher) => s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': name, 'educationalLevel': 'x', 'maxCapacity': 5,
        'assignedTeacherId': teacher, 'locationOrMode': 'onsite', 'weeklySchedule': [],
        'sessionDurationMinutes': 60, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 't1');
  await circle('cB', 'حلقة المغرب', 't2');
  for (final (id, name) in [('t1', 'المعلمة فاطمة'), ('t2', 'المعلمة خديجة')]) {
    await s.setDoc('teachers/$id', {
      'centerId': 'center-1', 'userId': id, 'fullName': name, 'status': 'active',
      'assignedCircleIds': [], 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  Future<void> session(String id, String circle, String teacher, int day, String status) =>
      s.setDoc('schedules/$id', {
        'centerId': 'center-1', 'circleId': circle, 'teacherId': teacher, 'date': _day(day),
        'startTime': '08:00', 'endTime': '09:00', 'locationOrMode': 'onsite', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('recent', 'cA', 't1', -2, 'completed');
  await session('old', 'cA', 't1', -60, 'completed');
  Future<void> att(String sess, String student, String status) => s.setDoc('attendance/${sess}_$student', {
        'centerId': 'center-1', 'sessionId': sess, 'studentId': student, 'status': status,
        'recordedBy': 't1', 'createdAt': _day(-1), 'updatedAt': _day(-1),
      });
  await att('recent', 's1', 'present');
  await att('recent', 's2', 'absent');
  await att('old', 's1', 'absent'); // 60 days ago: outside the default 30-day window
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/reports');
    return app;
  }

  Finder cell(String text) => find.descendant(of: find.byType(DataTable), matching: find.text(text));

  testWidgets('the attendance report covers the chosen period and this center only', (tester) async {
    await open(tester);
    expect(find.textContaining('الفترة: آخر 30 يومًا'), findsOneWidget);
    expect(cell('أحمد علي'), findsOneWidget);
    expect(cell('طالب مركز آخر'), findsNothing);
    // s1: present in the window; the old absence is outside it -> 100%.
    expect(cell('100.0%'), findsOneWidget);
    expect(cell('0.0%'), findsOneWidget);   // s2 absent once
    expect(cell('—'), findsOneWidget);       // s3 has no records: no rate, not 0%
    expect(find.textContaining('النسبة = (حاضر + متأخر)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(cell('50.0%'), findsOneWidget); // s1 now has the old absence too
  });

  testWidgets('filtering by circle narrows the rows and the stated filters say so', (tester) async {
    await open(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حلقة المغرب').last);
    await tester.pumpAndSettle();
    expect(cell('جميلة'), findsOneWidget);
    expect(cell('أحمد علي'), findsNothing);
    expect(find.textContaining('الحلقة: حلقة المغرب'), findsOneWidget);
    expect(find.textContaining('1 صف'), findsOneWidget);
  });

  testWidgets('teacher and circle reports show counts and state what they are not', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'المعلمون'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ليست تقييمًا لجودة التدريس'), findsOneWidget);
    expect(cell('المعلمة فاطمة'), findsOneWidget);
    expect(cell('2'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'الحلقات'));
    await tester.pumpAndSettle();
    expect(cell('حلقة الفجر'), findsOneWidget);
    expect(cell('حلقة المغرب'), findsOneWidget);
  });

  testWidgets('the CSV copy puts the exact table on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await open(tester);
    await tester.tap(find.text('نسخ بصيغة CSV'));
    await tester.pumpAndSettle();
    expect(copied, isNotNull);
    final lines = copied!.split('\r\n');
    expect(lines.first, 'الطالب,الحلقة,حاضر,متأخر,غائب,معذور,النسبة');
    expect(lines, hasLength(4)); // header + 3 active students of this center
    expect(copied, contains('أحمد علي,حلقة الفجر,1,0,0,0,100.0%'));
    expect(copied, isNot(contains('طالب مركز آخر')));
    expect(find.textContaining('نُسخ التقرير'), findsOneWidget);
  });

  testWidgets('the follow-up screen lists cases with their reasons and states it is not a verdict',
      (tester) async {
    final app = await bootApp(tester, accounts: _accounts, seed: (s) async {
      await _seed(s);
      await s.setDoc('schedules/empty', {
        'centerId': 'center-1', 'circleId': 'cB', 'teacherId': 't2', 'date': _day(-3),
        'startTime': '08:00', 'endTime': '09:00', 'locationOrMode': 'onsite', 'status': 'completed',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
      await s.setDoc('learning_tasks/late', {
        'centerId': 'center-1', 'planId': 'p', 'studentId': 's1', 'teacherId': 't1',
        'taskType': 'recentRevision', 'surah': 1, 'startAyah': 1, 'endAyah': 2,
        'assignedDate': _day(-10), 'dueDate': _day(-4), 'teacherInstructions': '',
        'status': 'inProgress', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
    });
    await app.signIn('dir@x.com', 'pw');
    await app.go('/director/supervision');
    expect(find.textContaining('وليست حكمًا على أحد'), findsOneWidget);
    expect(find.text('مهام متأخرة (1)'), findsOneWidget);
    expect(find.textContaining('مهمة تجاوزت موعدها بـ 4 يومًا'), findsOneWidget);
    expect(find.text('جلسات بلا حضور (1)'), findsOneWidget);
    expect(find.textContaining('جلسة منتهية بلا أي سجل حضور'), findsOneWidget);
    // The student case opens the student's profile.
    await tester.tap(find.text('أحمد علي'));
    await tester.pumpAndSettle();
    expect(find.text('ملف الطالب'), findsOneWidget);
  });
}
