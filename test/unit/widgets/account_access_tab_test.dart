import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/students/account_access_tab.dart';

class FakeAccessService implements AccountAccessService {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> enableStudentAccess(
      {required String studentId, required String email}) async {
    calls.add('enable:$studentId:$email');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> setSuspended(
      {required String studentId, required bool suspend}) async {
    calls.add('suspend:$studentId:$suspend');
    if (failWith != null) throw failWith!;
  }

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
  Future<void> resendActivation(String email) async {
    calls.add('resend:$email');
  }
}

Student _student({
  AccountMode mode = AccountMode.none,
  String? uid,
}) =>
    Student(
      studentId: 's1',
      centerId: 'center-1',
      fullName: 'طالب',
      enrollmentStatus: EnrollmentStatus.active,
      accountMode: mode,
      authUserId: uid,
      educationalLevel: 'مبتدئ',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _app(FakeAccessService service, Student student, VoidCallback onChanged) {
  return ProviderScope(
    overrides: [accountAccessServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AccountAccessTab(student: student, onChanged: onChanged),
        ),
      ),
    ),
  );
}

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton)));
  return button.onPressed != null;
}

void main() {
  testWidgets('accountless student: only Enable is available', (tester) async {
    await tester.pumpWidget(_app(FakeAccessService(), _student(), () {}));

    expect(_enabled(tester, 'تفعيل دخول الطالب'), isTrue);
    expect(_enabled(tester, 'تعليق الدخول'), isFalse);
    expect(_enabled(tester, 'إعادة تفعيل الدخول'), isFalse);
    expect(find.text('لا يوجد حساب دخول لتغييره'), findsOneWidget);
  });

  testWidgets('invalid email is rejected without calling the backend',
      (tester) async {
    final service = FakeAccessService();
    await tester.pumpWidget(_app(service, _student(), () {}));

    await tester.tap(find.text('تفعيل دخول الطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
    expect(service.calls, isEmpty);
  });

  testWidgets('valid email enables access (trimmed), then refreshes',
      (tester) async {
    final service = FakeAccessService();
    var changed = 0;
    await tester.pumpWidget(_app(service, _student(), () => changed++));

    await tester.tap(find.text('تفعيل دخول الطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Student@Example.com ');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(service.calls, ['enable:s1:Student@Example.com']);
    expect(changed, 1);
    expect(find.text('تم تفعيل الدخول وإرسال رسالة التفعيل'), findsOneWidget);
  });

  testWidgets('backend failure shows the message and does not refresh',
      (tester) async {
    final service = FakeAccessService()
      ..failWith = AccountAccessException('هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.');
    var changed = 0;
    await tester.pumpWidget(_app(service, _student(), () => changed++));

    await tester.tap(find.text('تفعيل دخول الطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a@b.com');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(find.text('هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.'),
        findsOneWidget);
    expect(changed, 0);
  });

  testWidgets('activation-email failure still refreshes (account exists)',
      (tester) async {
    final service = FakeAccessService()..failWith = ActivationEmailException();
    var changed = 0;
    await tester.pumpWidget(_app(service, _student(), () => changed++));

    await tester.tap(find.text('تفعيل دخول الطالب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a@b.com');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(changed, 1);
    expect(find.textContaining('تعذر إرسال رسالة التفعيل'), findsOneWidget);
  });

  testWidgets('suspend asks for confirmation; cancel does nothing',
      (tester) async {
    final service = FakeAccessService();
    final student = _student(mode: AccountMode.loginEnabled, uid: 'u1');
    await tester.pumpWidget(_app(service, student, () {}));

    expect(_enabled(tester, 'تفعيل دخول الطالب'), isFalse);
    expect(_enabled(tester, 'تعليق الدخول'), isTrue);

    await tester.tap(find.text('تعليق الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('تعليق دخول الطالب؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
  });

  testWidgets('confirmed suspend calls the backend', (tester) async {
    final service = FakeAccessService();
    final student = _student(mode: AccountMode.loginEnabled, uid: 'u1');
    await tester.pumpWidget(_app(service, student, () {}));

    await tester.tap(find.text('تعليق الدخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تعليق'));
    await tester.pumpAndSettle();

    expect(service.calls, ['suspend:s1:true']);
    expect(find.text('تم تعليق الدخول'), findsOneWidget);
  });

  testWidgets('suspended student can only be reactivated', (tester) async {
    final student = _student(mode: AccountMode.suspended, uid: 'u1');
    await tester.pumpWidget(_app(FakeAccessService(), student, () {}));

    expect(_enabled(tester, 'تفعيل دخول الطالب'), isFalse);
    expect(_enabled(tester, 'تعليق الدخول'), isFalse);
    expect(_enabled(tester, 'إعادة تفعيل الدخول'), isTrue);
  });

  test('accessErrorMessage maps codes and hides unknown internals', () {
    expect(accessErrorMessage('already-exists'), contains('مستخدم'));
    expect(accessErrorMessage('permission-denied'), contains('صلاحية'));
    expect(accessErrorMessage('something-internal-xyz'), contains('تعذر الاتصال'));
  });
}
