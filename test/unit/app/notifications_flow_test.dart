import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';

import '../../support/app_harness.dart';

const _accounts = {
  'dir@x.com': ('pw', 'dir-1'),
  'tea@x.com': ('pw', 'tea-1'),
  'stu@x.com': ('pw', 'u-s1'),
};

Future<void> _seed(FakeFirestoreDataSource s) async {
  await seedUser(s, 'dir-1', 'director', name: 'مديرة الدار');
  await seedUser(s, 'tea-1', 'teacher', name: 'المعلمة فاطمة');
  await seedUser(s, 'tea-2', 'teacher', name: 'معلمة أخرى');
  await seedUser(s, 'u-s1', 'student', name: 'بسمة', studentId: 's1');
  await seedUser(s, 'u-x', 'teacher', name: 'مركز آخر', centerId: 'center-2');
  await s.setDoc('students/s1', {
    'centerId': 'center-1', 'fullName': 'بسمة', 'accountMode': 'loginEnabled', 'authUserId': 'u-s1',
    'enrollmentStatus': 'active', 'assignedTeacherIds': ['tea-1'], 'currentCircleId': 'cA',
    'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
  });
  Future<void> circle(String id, String name, String teacher) => s.setDoc('circles/$id', {
        'centerId': 'center-1', 'name': name, 'educationalLevel': 'x', 'maxCapacity': 5,
        'assignedTeacherId': teacher, 'locationOrMode': 'onsite', 'weeklySchedule': [],
        'sessionDurationMinutes': 60, 'status': 'active',
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await circle('cA', 'حلقة الفجر', 'tea-1');
  await circle('cB', 'حلقة المغرب', 'tea-2');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<AppHarness> open(WidgetTester tester, String email, [String? path]) async {
    final app = await bootApp(tester, accounts: _accounts, seed: _seed);
    await app.signIn(email, 'pw');
    if (path != null) await app.go(path);
    return app;
  }

  group('announcements', () {
    testWidgets('the form validates and shows who will actually be reached', (tester) async {
      final app = await open(tester, 'dir@x.com', '/director/announcements');
      expect(find.text('لم تُرسل إعلانات بعد.'), findsOneWidget);
      await tester.tap(find.text('إعلان جديد'));
      await tester.pumpAndSettle();

      expect(find.text('سيصل إلى 3 مستلم'), findsOneWidget); // 2 teachers + 1 student, not the sender or another center
      await tester.tap(find.text('إرسال الآن'));
      await tester.pumpAndSettle();
      expect(find.text('العنوان مطلوب.'), findsOneWidget);
      expect(await app.store.query('notifications', where: []), isEmpty);
    });

    testWidgets('a circle-only announcement reaches exactly that circle, and says so before sending',
        (tester) async {
      final app = await open(tester, 'dir@x.com', '/director/announcements');
      await tester.tap(find.text('إعلان جديد'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'العنوان *'), 'تغيير موعد');
      await tester.enterText(find.widgetWithText(TextField, 'نص الإعلان *'), 'الحلقة غدًا بعد العصر');
      await tester.tap(find.byType(DropdownButtonFormField<AudienceType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حلقات محددة').last);
      await tester.pumpAndSettle();

      expect(find.text('سيصل إلى 0 مستلم'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'حلقة الفجر'));
      await tester.pumpAndSettle();
      expect(find.text('سيصل إلى 2 مستلم'), findsOneWidget); // the student's login + the circle's teacher

      await tester.dragUntilVisible(find.text('إرسال الآن'), find.byType(Scrollable).first, const Offset(0, -200));
      await tester.tap(find.text('إرسال الآن'));
      await tester.pumpAndSettle();

      final notes = await app.store.query('notifications', where: []);
      expect(notes.map((n) => n['recipientUserId']).toSet(), {'u-s1', 'tea-1'});
      expect(find.text('أُرسل الإعلان إلى 2 مستلم'), findsOneWidget);
      expect(find.text('تغيير موعد'), findsOneWidget); // listed after sending
      expect(find.textContaining('وصل إلى 2'), findsOneWidget);
    });
  });

  group('inbox', () {
    Future<void> sendToEveryone(AppHarness app, WidgetTester tester) async {
      await app.go('/director/announcements');
      await tester.tap(find.text('إعلان جديد'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'العنوان *'), 'اجتماع عام');
      await tester.enterText(find.widgetWithText(TextField, 'نص الإعلان *'), 'يوم الخميس');
      await tester.tap(find.text('إرسال الآن'));
      await tester.pumpAndSettle();
    }

    testWidgets('a teacher sees an unread badge, reads it, and only their own notifications',
        (tester) async {
      final app = await open(tester, 'dir@x.com');
      await sendToEveryone(app, tester);
      await app.signOut();
      await app.signIn('tea@x.com', 'pw');

      expect(find.text('1'), findsWidgets); // badge
      await tester.tap(find.byTooltip('الإشعارات (1 غير مقروء)'));
      await tester.pumpAndSettle();
      expect(find.text('اجتماع عام'), findsOneWidget);
      expect(find.text('تعليم الكل كمقروء'), findsOneWidget);

      await tester.tap(find.text('اجتماع عام'));
      await tester.pumpAndSettle();
      expect(find.text('تعليم الكل كمقروء'), findsNothing); // nothing unread now
      final stored = (await app.store.query('notifications', where: []))
          .singleWhere((n) => n['recipientUserId'] == 'tea-1');
      expect(stored['read'], true);
      // The others' copies are untouched.
      expect((await app.store.query('notifications', where: []))
          .where((n) => n['recipientUserId'] != 'tea-1')
          .every((n) => n['read'] == false), isTrue);
    });

    testWidgets('mark all as read, and the empty inbox says so', (tester) async {
      final app = await open(tester, 'dir@x.com');
      await sendToEveryone(app, tester);
      await app.signOut();
      await app.signIn('stu@x.com', 'pw');
      await app.go('/student/notifications');
      expect(find.text('اجتماع عام'), findsOneWidget);
      await tester.tap(find.text('تعليم الكل كمقروء'));
      await tester.pumpAndSettle();
      expect(find.text('تعليم الكل كمقروء'), findsNothing);

      await app.signOut();
      await app.signIn('dir@x.com', 'pw');
      await app.go('/director/notifications');
      expect(find.text('لا توجد إشعارات.'), findsOneWidget); // the sender is not a recipient
    });
  });
}
