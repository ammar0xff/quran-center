import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/features/student/widgets/student_scaffold.dart';

/// The student's own profile: only fields that are theirs to see.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StudentScaffold(
      title: 'حسابي',
      navIndex: 4,
      builder: (context, ref, d) {
        final s = d.student;
        Widget row(String l, String v) => Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.space12,
                  horizontal: DesignTokens.space16),
              child: Row(children: [
                SizedBox(
                    width: 110,
                    child: Text(l,
                        style: const TextStyle(
                            color: DesignTokens.secondaryText))),
                Expanded(
                    child: Text(v,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            );
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            ProfileBanner(
                name: s.displayName, subtitle: d.circle?.name ?? 'طالب'),
            const SizedBox(height: DesignTokens.space12),
            Card(
              child: Column(children: [
                row('الاسم', s.fullName),
                if (s.preferredName != null) ...[
                  const Divider(height: 1),
                  row('الاسم المفضل', s.preferredName!),
                ],
                const Divider(height: 1),
                row('المستوى', s.educationalLevel),
                const Divider(height: 1),
                row('الحلقة', d.circle?.name ?? 'غير مسجّل في حلقة'),
              ]),
            ),
            const SizedBox(height: DesignTokens.space24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authGatewayProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }
}
