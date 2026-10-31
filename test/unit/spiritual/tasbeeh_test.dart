import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/features/spiritual/screens/tasbeeh_and_azkar_screen.dart';

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TasbeehAndAzkarScreen(),
      ),
    );
  }

  group('TasbeehAndAzkarScreen Tests', () {
    testWidgets('renders reassurance banner, counter, and tab options',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check reassurance banner
      expect(find.text('انتهت فترة اشتراك داركم'), findsOneWidget);
      expect(
          find.text('بياناتكم وطلابكم وحلقاتكم وسجلاتكم محفوظة تماماً بأمان 🔒'),
          findsOneWidget);
      expect(find.text('تجديد'), findsOneWidget);

      // Check initial counter value 0 and total counter
      expect(find.text('0'), findsOneWidget);
      expect(find.text('مجموع التسبيحات: 0'), findsOneWidget);
      expect(find.text('المس للتسبيح'), findsOneWidget);
      expect(find.text('المسبحة الذكية'), findsOneWidget);
      expect(find.text('أذكار الصباح والمساء'), findsOneWidget);
      expect(find.text('أدعية وأذكار'), findsOneWidget);
    });

    testWidgets('tapping tasbeeh button increments counter', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tasbeehBtn = find.text('المس للتسبيح');
      expect(tasbeehBtn, findsOneWidget);

      await tester.tap(tasbeehBtn);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('مجموع التسبيحات: 1'), findsOneWidget);

      await tester.tap(tasbeehBtn);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('مجموع التسبيحات: 2'), findsOneWidget);
    });

    testWidgets('reset button resets current counter to 0', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tasbeehBtn = find.text('المس للتسبيح');
      await tester.tap(tasbeehBtn);
      await tester.tap(tasbeehBtn);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      // Tap reset button
      final resetBtn = find.widgetWithText(OutlinedButton, 'تصفير');
      expect(resetBtn, findsOneWidget);
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      // Total session count is retained
      expect(find.text('مجموع التسبيحات: 2'), findsOneWidget);
    });

    testWidgets('switches between tabs and shows azkar lists', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap morning/evening tab
      await tester.tap(find.text('أذكار الصباح والمساء'));
      await tester.pumpAndSettle();

      expect(find.text('سيد الاستغفار'), findsOneWidget);
      expect(find.text('آية الكرسي'), findsOneWidget);

      // Tap post-prayer tab
      await tester.tap(find.text('أدعية وأذكار'));
      await tester.pumpAndSettle();

      expect(find.text('الاستغفار بعد الصلاة'), findsOneWidget);
      expect(find.text('التسبيح والتحميد والتكبير'), findsOneWidget);
    });
  });
}
