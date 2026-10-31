import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/features/director/widgets/meshkah_identity_input.dart';

void main() {
  Widget buildWidget({
    required void Function(String email, String? tempPassword) onChanged,
    String initialUsername = '',
  }) {
    return ProviderScope(
      overrides: [
        centerIdProvider.overrideWithValue('dar-al-nour'),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: MeshkahIdentityInput(
                  initialUsername: initialUsername,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('MeshkahIdentityInput Tests', () {
    testWidgets('defaults to Meshkah direct identity with center slug suffix',
        (tester) async {
      String resolvedEmail = '';
      String? resolvedPassword;

      await tester.pumpWidget(buildWidget(
        onChanged: (email, pwd) {
          resolvedEmail = email;
          resolvedPassword = pwd;
        },
      ));
      await tester.pumpAndSettle();

      // Check segments and suffix text
      expect(find.text('معرف مشكاة المباشر'), findsOneWidget);
      expect(find.text('بريد إلكتروني تقليدي'), findsOneWidget);
      expect(find.text('@dar-al-nour.meshkah'), findsWidgets);

      // Enter username
      await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم المستخدم بالإنجليزية *'),
          'ahmed.ali');
      await tester.pumpAndSettle();

      expect(resolvedEmail, 'ahmed.ali@dar-al-nour.meshkah');
      expect(resolvedPassword, isNotNull);
      expect(resolvedPassword!.length, greaterThanOrEqualTo(6));
    });

    testWidgets('switching to conventional email allows entering custom email',
        (tester) async {
      String resolvedEmail = '';

      await tester.pumpWidget(buildWidget(
        onChanged: (email, _) => resolvedEmail = email,
      ));
      await tester.pumpAndSettle();

      // Tap conventional email segment
      await tester.tap(find.text('بريد إلكتروني تقليدي'));
      await tester.pumpAndSettle();

      // Enter standard email
      await tester.enterText(
          find.widgetWithText(TextFormField, 'البريد الإلكتروني الشخصي *'),
          'custom.teacher@gmail.com');
      await tester.pumpAndSettle();

      expect(resolvedEmail, 'custom.teacher@gmail.com');
    });

    testWidgets('copy credentials button copies text to clipboard',
        (tester) async {
      await tester.pumpWidget(buildWidget(
        initialUsername: 'fatima',
        onChanged: (_, __) {},
      ));
      await tester.pumpAndSettle();

      final copyBtn =
          find.text('نسخ بيانات الدخول لمشاركتها مع المستخدم');
      expect(copyBtn, findsOneWidget);

      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(find.text('تم نسخ بيانات الدخول إلى الحافظة بنجاح 📋'),
          findsOneWidget);
    });
  });
}
