import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/core/sync/outbox.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/models/enums.dart';

import '../../support/app_harness.dart';

const _accounts = {
  'tea@x.com': ('pw', 'tea-1'),
  'new@x.com': ('pw', 'tea-new'),
};

int _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset).millisecondsSinceEpoch;
}

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  await seedUser(s, 'tea-new', 'teacher', name: 'معلمة جديدة');

  Future<void> circle(String id, String name, String teacher) =>
      s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': name, 'educationalLevel': 'x', 'maxCapacity': 10,
        'assignedTeacherId': teacher, 'locationOrMode': 'onsite', 'weeklySchedule': [],
        'sessionDurationMinutes': 60, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 'tea-1');
  await circle('cB', 'حلقة المغرب', 'tea-2');

  Future<void> session(String id, String circleId, String teacher, int day, String status,
          {String start = '08:00'}) =>
      s.setDoc('schedules/$id', {
        'centerId': 'center-1', 'circleId': circleId, 'teacherId': teacher, 'date': _day(day),
        'startTime': start, 'endTime': '09:00', 'locationOrMode': 'onsite', 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await session('today', 'cA', 'tea-1', 0, 'scheduled');
  await session('todayDone', 'cA', 'tea-1', 0, 'completed', start: '06:00');
  await session('tomorrow', 'cA', 'tea-1', 1, 'scheduled');
  await session('others', 'cB', 'tea-2', 0, 'scheduled');

  for (final (id, name) in [('s1', 'بسمة خالد'), ('s2', 'أحمد علي')]) {
    await s.setDoc('students/$id', {
      'centerId': 'center-1', 'fullName': name, 'accountMode': 'none',
      'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-1'],
      'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
    await s.setDoc('enrollments/e_$id', {
      'centerId': 'center-1', 'studentId': id, 'circleId': 'cA', 'teacherId': 'tea-1',
      'startDate': 1700000000000, 'status': 'active',
      'createdAt': 1700000000000, 'updatedAt': 1700000000000,
    });
  }
  await s.setDoc('students/s9', {
    'centerId': 'center-1', 'fullName': 'طالب معلم آخر', 'accountMode': 'none',
    'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-2'],
    'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
}

Finder _chip(String student, String label) => find.descendant(
    of: find.ancestor(of: find.text(student), matching: find.byType(Card)),
    matching: find.widgetWithText(ChoiceChip, label));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, {String as = 'tea@x.com', String? path}) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn(as, 'pw');
    if (path != null) await app.go(path);
    return app;
  }

  group('home', () {
    testWidgets('shows this teacher\'s counts and today\'s sessions only', (tester) async {
      await open(tester);
      expect(find.text('المعلمة فاطمة'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // my students (s9 belongs to another teacher)
      expect(find.text('1'), findsWidgets); // my circles
      expect(find.text('لم تبدأ'), findsOneWidget);
      expect(find.text('منتهية'), findsOneWidget);
      // The other teacher's session is not shown: only cA's two sessions are.
      expect(find.text('حلقة الفجر'), findsNWidgets(3)); // 2 today + 1 upcoming
      expect(find.text('حلقة المغرب'), findsNothing);
    });

    testWidgets('a teacher with no assignments sees a clear message, not zeros', (tester) async {
      await open(tester, as: 'new@x.com');
      expect(find.textContaining('لم تُسند إليك حلقات أو طلاب بعد'), findsOneWidget);
    });
  });

  group('session', () {
    Future<AppHarness> openToday(WidgetTester tester) async {
      final app = await open(tester, path: '/teacher/sessions/today');
      return app;
    }

    testWidgets('cannot mark attendance before the session starts', (tester) async {
      final app = await openToday(tester);
      expect(find.text('بدء الجلسة'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(_chip('بسمة خالد', 'حاضر'));
      expect(chip.onSelected, isNull);
      expect(await app.store.query('attendance', where: []), isEmpty);
    });

    testWidgets('start, record, fix, then complete with the missing count confirmed',
        (tester) async {
      final app = await openToday(tester);
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('schedules/today'))!['status'], 'inProgress');

      // Roster is by name: أحمد before بسمة.
      expect(tester.getTopLeft(find.text('أحمد علي')).dy,
          lessThan(tester.getTopLeft(find.text('بسمة خالد')).dy));

      await tester.tap(_chip('بسمة خالد', 'غائب'));
      await tester.pumpAndSettle();
      var rec = (await app.store.getDoc('attendance/today_s1'))!;
      expect(rec['status'], 'absent');
      expect(rec['recordedBy'], 'tea-1');

      // Fixing a mistake while in progress rewrites the same record.
      await tester.tap(_chip('بسمة خالد', 'حاضر'));
      await tester.pumpAndSettle();
      rec = (await app.store.getDoc('attendance/today_s1'))!;
      expect(rec['status'], 'present');
      expect(await app.store.query('attendance', where: []), hasLength(1));
      expect(find.textContaining('سُجِّل 1'), findsOneWidget);

      await tester.dragUntilVisible(
          find.text('إنهاء الجلسة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('إنهاء الجلسة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لم يُسجَّل حضور 1 طالبًا'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'إنهاء الجلسة').last);
      await tester.pumpAndSettle();

      expect((await app.store.getDoc('schedules/today'))!['status'], 'completed');
      expect(find.textContaining('تعديل الحضور بعد انتهائها يتم عبر الإدارة'), findsOneWidget);
      // Read-only now.
      expect(tester.widget<ChoiceChip>(_chip('بسمة خالد', 'غائب')).onSelected, isNull);
    });

    testWidgets('cancelling the finish dialog leaves the session running', (tester) async {
      final app = await openToday(tester);
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.text('إنهاء الجلسة'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('إنهاء الجلسة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('schedules/today'))!['status'], 'inProgress');
    });

    testWidgets('a session of a future day cannot be started', (tester) async {
      final app = await open(tester, path: '/teacher/sessions/tomorrow');
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      expect(find.text('يمكن بدء الجلسة في يومها فقط.'), findsOneWidget);
      expect((await app.store.getDoc('schedules/tomorrow'))!['status'], 'scheduled');
    });

    testWidgets('another teacher\'s session is simply not found', (tester) async {
      await open(tester, path: '/teacher/sessions/others');
      expect(find.text('لم يتم العثور على الجلسة.'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);
    });

    group('offline', () {
      Future<(AppHarness, _OfflineStore, StreamController<void>)> live(WidgetTester tester,
          {MemoryOutboxStorage? storage}) async {
        final store = _OfflineStore();
        final net = StreamController<void>.broadcast();
        final app = await bootApp(tester,
            accounts: _accounts, seed: _seed, store: store, connectivity: net.stream,
            outboxStorage: storage);
        addTearDown(net.close);
        await app.signIn('tea@x.com', 'pw');
        await app.go('/teacher/sessions/today');
        await tester.tap(find.text('بدء الجلسة'));
        await tester.pumpAndSettle();
        return (app, store, net);
      }

      Future<void> reconnect(WidgetTester tester, _OfflineStore store, StreamController<void> net) async {
        store.offline = false;
        net.add(null);
        await tester.pumpAndSettle();
      }

      testWidgets('attendance marked offline shows at once, is kept, and syncs when the network returns',
          (tester) async {
        final (_, store, net) = await live(tester);
        store.offline = true;
        await tester.tap(_chip('بسمة خالد', 'حاضر'));
        await tester.pumpAndSettle();

        // The teacher sees their choice and an honest "not synced yet" state.
        expect(tester.widget<ChoiceChip>(_chip('بسمة خالد', 'حاضر')).selected, isTrue);
        expect(find.text('بانتظار المزامنة'), findsOneWidget);
        expect(find.textContaining('1 تغييرات محفوظة على جهازك بانتظار المزامنة'), findsOneWidget);
        expect(await store.peek('attendance/today_s1'), isNull);

        await reconnect(tester, store, net);
        expect((await store.peek('attendance/today_s1'))!['status'], 'present');
        expect(find.textContaining('بانتظار المزامنة'), findsNothing);
        expect(tester.widget<ChoiceChip>(_chip('بسمة خالد', 'حاضر')).selected, isTrue);
      });

      testWidgets('changing your mind offline sends only the final value, once', (tester) async {
        final (_, store, net) = await live(tester);
        store.offline = true;
        await tester.tap(_chip('بسمة خالد', 'غائب'));
        await tester.pumpAndSettle();
        await tester.tap(_chip('بسمة خالد', 'متأخر'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 تغييرات'), findsOneWidget); // coalesced, not 2

        await reconnect(tester, store, net);
        final all = await store.peekAll('attendance');
        expect(all, hasLength(1));
        expect(all.single['status'], 'late');
      });

      testWidgets('the session cannot be finished while changes are still waiting', (tester) async {
        final (_, store, net) = await live(tester);
        store.offline = true;
        await tester.tap(_chip('بسمة خالد', 'حاضر'));
        await tester.pumpAndSettle();

        await tester.dragUntilVisible(
            find.text('إنهاء الجلسة'), find.byType(ListView), const Offset(0, -200));
        await tester.tap(find.text('إنهاء الجلسة'));
        await tester.pumpAndSettle();
        expect(find.textContaining('لا يمكن إنهاء الجلسة قبل مزامنة 1 تغييرات'), findsOneWidget);
        expect((await store.peek('schedules/today'))!['status'], 'inProgress');

        // Back online: the same action now works and nothing was lost.
        await reconnect(tester, store, net);
        await tester.tap(find.text('إنهاء الجلسة'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'إنهاء الجلسة').last);
        await tester.pumpAndSettle();
        expect((await store.peek('schedules/today'))!['status'], 'completed');
        expect((await store.peek('attendance/today_s1'))!['status'], 'present');
      });

      testWidgets('a change the server rejects is shown with its reason and can be discarded',
          (tester) async {
        final (_, store, _) = await live(tester);
        // The session was ended elsewhere (for example from another device).
        await store.setDoc('schedules/today', {...(await store.peek('schedules/today'))!, 'status': 'completed'});
        await tester.tap(_chip('بسمة خالد', 'حاضر'));
        await tester.pumpAndSettle();

        expect(find.textContaining('رُفض:'), findsOneWidget);
        expect(find.textContaining('1 تغييرات رفضها الخادم'), findsOneWidget);
        expect(await store.peek('attendance/today_s1'), isNull);

        await tester.tap(find.text('عرض'));
        await tester.pumpAndSettle();
        expect(find.text('تغييرات رفضها الخادم'), findsOneWidget);
        await tester.tap(find.text('تجاهل'));
        await tester.pumpAndSettle();
        expect(find.textContaining('رفضها الخادم'), findsNothing);
      });

      testWidgets('what was queued survives closing the app', (tester) async {
        final storage = MemoryOutboxStorage();
        final (_, store, _) = await live(tester, storage: storage);
        store.offline = true;
        await tester.tap(_chip('بسمة خالد', 'غائب'));
        await tester.pumpAndSettle();
        expect(storage.data.values.single, contains('att:today:s1'));

        // "Restart": a brand-new app over the same device storage, now online.
        await tester.pumpWidget(const SizedBox());
        store.offline = false;
        final app = await bootApp(tester,
            accounts: _accounts, seed: (_) async {}, store: store, outboxStorage: storage);
        await app.signIn('tea@x.com', 'pw');
        await tester.pumpAndSettle();
        expect((await store.peek('attendance/today_s1'))!['status'], 'absent');
        expect(storage.data.values.single, '[]');
      });
    });
  });

  group('assessment', () {
    Future<AppHarness> openLive(WidgetTester tester) async {
      final app = await open(tester, path: '/teacher/sessions/today');
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      return app;
    }

    Future<void> openForm(WidgetTester tester, String student) async {
      await tester.tap(find.descendant(
          of: find.ancestor(of: find.text(student), matching: find.byType(Card)),
          matching: find.text('تسميع')));
      await tester.pumpAndSettle();
    }

    Future<void> include(WidgetTester tester, String wird) async {
      final sw = find.widgetWithText(SwitchListTile, wird);
      await tester.dragUntilVisible(sw, find.byType(Scrollable).first, const Offset(0, -150));
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, AssessmentType t, int surah, String from, String to,
        {WirdGrade? grade}) async {
      final dd = find.byKey(ValueKey('surah_${t.name}'));
      await tester.dragUntilVisible(dd, find.byType(Scrollable).first, const Offset(0, -150));
      // Choose the surah as the dropdown's own callback would (the long menu is
      // exercised separately); then fill the ayah range.
      tester.widget<DropdownButtonFormField<int>>(dd).onChanged!(surah);
      await tester.pumpAndSettle();
      final card = find.ancestor(of: dd, matching: find.byType(Card));
      await tester.enterText(find.descendant(of: card, matching: find.widgetWithText(TextField, 'من آية *')), from);
      await tester.enterText(find.descendant(of: card, matching: find.widgetWithText(TextField, 'إلى آية *')), to);
      if (grade != null) {
        final chip = find.byKey(ValueKey('grade_${t.name}_${grade.name}'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
    }

    Future<void> save(WidgetTester tester) async {
      await tester.dragUntilVisible(find.text('حفظ التسميع'), find.byType(Scrollable).first, const Offset(0, -300));
      await tester.tap(find.text('حفظ التسميع'));
      await tester.pumpAndSettle();
    }

    testWidgets('the Assess button exists only while the session is in progress', (tester) async {
      await open(tester, path: '/teacher/sessions/today');
      expect(find.text('تسميع'), findsNothing);
    });

    testWidgets('saving with no wird chosen, or a wird without a mark, writes nothing', (tester) async {
      final app = await openLive(tester);
      await openForm(tester, 'بسمة خالد');
      await save(tester);
      expect(find.text('اختر ورد واحدًا على الأقل مما سمعته.'), findsOneWidget);

      await include(tester, 'ورد الحفظ');
      await fill(tester, AssessmentType.newMemorization, 1, '1', '7'); // no mark
      await save(tester);
      expect(find.text('اختر التقدير'), findsWidgets);
      expect(await app.store.query('memorization_records', where: []), isEmpty);

      // The range is checked against the real surah length.
      await fill(tester, AssessmentType.newMemorization, 1, '1', '9', grade: WirdGrade.good);
      await save(tester);
      expect(find.text('آية النهاية بين 1 و 7'), findsOneWidget);
      expect(await app.store.query('memorization_records', where: []), isEmpty);
    });

    testWidgets('one visit: three marked wirds and the new portion, saved together under one visit',
        (tester) async {
      final app = await openLive(tester);
      await openForm(tester, 'بسمة خالد');

      await include(tester, 'ورد الحفظ');
      await fill(tester, AssessmentType.newMemorization, 1, '1', '7', grade: WirdGrade.excellent);
      await include(tester, 'مراجعة: ماضي قريب');
      await fill(tester, AssessmentType.recentRevision, 112, '1', '4', grade: WirdGrade.veryGood);
      await include(tester, 'مراجعة: ماضي بعيد');
      await fill(tester, AssessmentType.longTermRevision, 113, '1', '5', grade: WirdGrade.repeat);
      await include(tester, 'الجديد');
      await fill(tester, AssessmentType.newAssignment, 114, '1', '6'); // no mark for the new portion
      await tester.enterText(find.widgetWithText(TextField, 'ملاحظة تراها الطالبة/الطالب'), 'أحسنتِ');
      await tester.enterText(find.widgetWithText(TextField, 'ملاحظة خاصة بالمعلم'), 'سرية');
      await save(tester);

      final recs = await app.store.query('memorization_records', where: []);
      expect(recs, hasLength(4));
      expect({for (final r in recs) r['assessmentType'] as String: r['grade']}, {
        'newMemorization': 'excellent',
        'recentRevision': 'veryGood',
        'longTermRevision': 'repeat',
        'newAssignment': null,
      });
      expect(recs.map((r) => r['visitId']).toSet(), hasLength(1));
      expect(recs.every((r) => r['studentId'] == 's1' && r['teacherId'] == 'tea-1'), isTrue);
      // Notes belong to the visit and are stored once; the private one never in the student-readable record.
      expect(recs.where((r) => r['studentVisibleFeedback'] == 'أحسنتِ'), hasLength(1));
      expect('$recs', isNot(contains('سرية')));
      expect((await app.store.query('private_teacher_notes', where: [])).single['note'], 'سرية');
      expect(find.text('تم حفظ التسميع'), findsOneWidget);
      expect(find.text('تسميعات اليوم: 4'), findsOneWidget);
    });

    testWidgets('leaving with unsaved input asks first; keeping editing stays', (tester) async {
      final app = await openLive(tester);
      await openForm(tester, 'بسمة خالد');
      await include(tester, 'ورد الحفظ');

      await Navigator.of(tester.element(find.text('حفظ التسميع'))).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('تجاهل التسميع؟'), findsOneWidget);
      await tester.tap(find.text('متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ التسميع'), findsOneWidget);

      await Navigator.of(tester.element(find.text('حفظ التسميع'))).maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تجاهل'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ التسميع'), findsNothing);
      expect(await app.store.query('memorization_records', where: []), isEmpty);
    });

    testWidgets('a wird saved offline is kept and written exactly once when back online', (tester) async {
      final store = _OfflineStore();
      final net = StreamController<void>.broadcast();
      addTearDown(net.close);
      final app = await bootApp(tester,
          accounts: _accounts, seed: _seed, store: store, connectivity: net.stream);
      await app.signIn('tea@x.com', 'pw');
      await app.go('/teacher/sessions/today');
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      await openForm(tester, 'أحمد علي');
      await include(tester, 'ورد الحفظ');
      await fill(tester, AssessmentType.newMemorization, 112, '1', '4', grade: WirdGrade.good);
      await tester.enterText(find.widgetWithText(TextField, 'ملاحظة خاصة بالمعلم'), 'سرية');

      store.offline = true;
      await save(tester);
      expect(find.text('حفظ التسميع'), findsNothing);
      expect(find.text('تسميعات اليوم: 1'), findsOneWidget);
      expect(find.textContaining('بانتظار المزامنة'), findsWidgets);
      expect(await store.peekAll('memorization_records'), isEmpty);

      store.offline = false;
      net.add(null);
      await tester.pumpAndSettle();
      net.add(null);
      await tester.pumpAndSettle();

      final records = await store.peekAll('memorization_records');
      expect(records, hasLength(1));
      expect(records.single['grade'], 'good');
      expect((await store.peekAll('private_teacher_notes')).single['note'], 'سرية');
      expect(find.textContaining('بانتظار المزامنة'), findsNothing);
    });
  });

  group('visiting students', () {
    testWidgets('a teacher adds a student from another circle, marks attendance and grades a wird',
        (tester) async {
      final app = await bootApp(tester, accounts: _accounts, seed: (s) async {
        await _seed(s);
        for (final (id, name, active) in [
          ('s1', 'بسمة خالد', true), ('s2', 'أحمد علي', true), ('s9', 'طالب معلمة أخرى', true), ('sOld', 'مؤرشف', false),
        ]) {
          await s.setDoc('student_directory/$id', {'centerId': 'center-1', 'fullName': name, 'active': active});
        }
      });
      await app.signIn('tea@x.com', 'pw');
      await app.go('/teacher/sessions/today');
      expect(find.text('إضافة طالب زائر من حلقة أخرى'), findsNothing); // not before the session starts
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(find.text('إضافة طالب زائر من حلقة أخرى'), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('إضافة طالب زائر من حلقة أخرى'));
      await tester.pumpAndSettle();
      expect(find.text('طالب معلمة أخرى'), findsOneWidget);
      expect(find.text('مؤرشف'), findsNothing);   // archived are not offered
      expect(find.text('بسمة خالد'), findsOneWidget); // only in the roster behind, not as an option
      await tester.tap(find.text('طالب معلمة أخرى'));
      await tester.pumpAndSettle();

      expect(((await app.store.getDoc('schedules/today'))!['guestStudentIds'] as List), ['s9']);
      expect(find.text('طالب معلمة أخرى (زائر)'), findsOneWidget);
      await tester.tap(_chip('طالب معلمة أخرى (زائر)', 'حاضر'));
      await tester.pumpAndSettle();
      expect((await app.store.getDoc('attendance/today_s9'))!['recordedBy'], 'tea-1');
    });
  });

  group('circles', () {
    testWidgets('lists only my circles with my student counts', (tester) async {
      await open(tester, path: '/teacher/circles');
      expect(find.text('حلقة الفجر'), findsOneWidget);
      expect(find.text('حلقة المغرب'), findsNothing);
      expect(find.textContaining('2 طالب'), findsOneWidget);
    });
  });
}

/// A store that can be "disconnected": every operation then fails the way a
/// dropped connection does, while [peek] still lets the test look at the data.
class _OfflineStore extends FakeFirestoreDataSource {
  bool offline = false;

  void _check() {
    if (offline) throw StateError('network down');
  }

  Future<Map<String, dynamic>?> peek(String path) => super.getDoc(path);
  Future<List<Map<String, dynamic>>> peekAll(String collection) =>
      super.query(collection, where: []);

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async {
    _check();
    return super.getDoc(path);
  }

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data, {bool merge = false}) async {
    _check();
    return super.setDoc(path, data, merge: merge);
  }

  @override
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    _check();
    return super.updateDoc(path, data);
  }

  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    _check();
    return super.commitBatch(ops);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String collection,
      {required List<QueryFilter> where, String? orderBy, bool descending = false, int? limit}) async {
    _check();
    return super.query(collection, where: where, orderBy: orderBy, descending: descending, limit: limit);
  }
}
