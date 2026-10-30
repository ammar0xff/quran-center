import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

/// Account menu for the teacher.
class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('المزيد'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            if (name != null)
              Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.space16),
                child: Text(name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            OutlinedButton.icon(
              onPressed: () => ref.read(authGatewayProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 2),
      ),
    );
  }
}
