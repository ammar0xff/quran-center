import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/students/add_student_screen.dart';

class _FakeAccess implements AccountAccessService {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> enableStudentAccess(
      {required String studentId, required String email}) async {
    calls.add('$studentId|$email');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> setSuspended(
      {required String studentId, required bool suspend}) async {}

  @override
  Future<void> createTeacher({
    required String fullName,
    required String email,
    String? phone,
    String? professionalNotes,
  }) async {}

  @override
  Future<void> setTeacherSuspended(
      {required String teacherId, required bool suspend}) async {}

  @override
  Future<void> resendActivation(String email) async {}
}

/// Fails the first N writes, like a dropped connection.
class _FlakyDataSource extends FakeFirestoreDataSource {
  _FlakyDataSource(this.failures);
  int failures;

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data,
      {bool merge = false}) async {
    if (failures > 0) {
      failures--;
      throw StateError('network down');
    }
    return super.setDoc(path, data, merge: merge);
  }
}

Future<void> _pump(
  WidgetTester tester,
  FakeFirestoreDataSource store,
  _FakeAccess access,
) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
        centerIdProvider.overrideWithValue('center-1'),
      firestoreDataSourceProvider.overrideWithValue(store),
      accountAccessServiceProvider.overrideWithValue(access),
    ],
    child: const MaterialApp(home: AddStudentScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<List<Map<String, dynamic>>> _students(FakeFirestoreDataSource s) =>
    s.query('students', where: []);

void main() {
  testWidgets('name is required; nothing is saved when blank', (tester) async {
    final store = FakeFirestoreDataSource();
    await _pump(tester, store, _FakeAccess());

    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
    expect(await _students(store), isEmpty);
  });

  testWidgets('accountless student is saved without touching the backend',
      (tester) async {
    final store = FakeFirestoreDataSource();
    final access = _FakeAccess();
    await _pump(tester, store, access);

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'سارة أحمد');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    final saved = await _students(store);
    expect(saved, hasLength(1));
    expect(saved.single['fullName'], 'سارة أحمد');
    expect(saved.single['accountMode'], 'none');
    expect(access.calls, isEmpty);
    expect(find.text('تم إضافة الطالب بنجاح'), findsOneWidget);
  });

  testWidgets('after saving, the button is disabled (no double submit)',
      (tester) async {
    final store = FakeFirestoreDataSource();
    await _pump(tester, store, _FakeAccess());

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'أحمد');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'تم الحفظ'));
    expect(button.onPressed, isNull);
    expect(await _students(store), hasLength(1));
  });

  testWidgets('choosing a login saves an ACCOUNTLESS profile, then requests the login',
      (tester) async {
    final store = FakeFirestoreDataSource();
    final access = _FakeAccess();
    await _pump(tester, store, access);

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'خالد');
    await tester.tap(find.text('إنشاء دخول للطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'khaled@example.com');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    final saved = (await _students(store)).single;
    // The profile never claims a login the backend has not created.
    expect(saved['accountMode'], 'none');
    expect(saved.containsKey('authUserId') && saved['authUserId'] != null, isFalse);
    expect(access.calls, ['${saved['id']}|khaled@example.com']);
    expect(find.text('تم إضافة الطالب وتفعيل دخوله'), findsOneWidget);
  });

  testWidgets('an invalid login email blocks the whole save', (tester) async {
    final store = FakeFirestoreDataSource();
    final access = _FakeAccess();
    await _pump(tester, store, access);

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'خالد');
    await tester.tap(find.text('إنشاء دخول للطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'nope');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
    expect(await _students(store), isEmpty);
    expect(access.calls, isEmpty);
  });

  testWidgets('login failure keeps the profile and reports the problem',
      (tester) async {
    final store = FakeFirestoreDataSource();
    final access = _FakeAccess()
      ..failWith = AccountAccessException('هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.');
    await _pump(tester, store, access);

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'خالد');
    await tester.tap(find.text('إنشاء دخول للطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'taken@example.com');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    expect(await _students(store), hasLength(1));
    expect(find.textContaining('لم يُفعَّل الدخول'), findsOneWidget);
    expect(find.textContaining('مستخدم بالفعل'), findsOneWidget);
  });

  testWidgets('retrying after a failed save rewrites the same profile, never a duplicate',
      (tester) async {
    final store = _FlakyDataSource(1);
    await _pump(tester, store, _FakeAccess());

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل *'), 'ليلى');
    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    // First attempt failed: nothing stored, form data kept, button usable.
    expect(find.textContaining('تعذر حفظ الطالب'), findsOneWidget);
    expect(await _students(store), isEmpty);
    expect(find.text('ليلى'), findsWidgets);

    await tester.tap(find.text('حفظ الطالب'));
    await tester.pumpAndSettle();

    expect(await _students(store), hasLength(1));
  });
}
