import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Sections without a tab of their own, plus the account menu.
class DirectorMoreScreen extends ConsumerWidget {
  const DirectorMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName;

    Widget tile(IconData icon, String title, String route) => Card(
          margin: const EdgeInsets.only(bottom: DesignTokens.space12),
          child: ListTile(
            leading: Icon(icon, color: DesignTokens.primaryDarkGreen),
            title: Text(title),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(route),
          ),
        );

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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            tile(Icons.schedule, 'إدارة الجدول', '/director/schedules'),
            tile(Icons.fact_check, 'إدارة الحضور', '/director/attendance'),
            tile(Icons.assignment_ind, 'تعيين طالب لحلقة',
                '/director/enrollments/assign'),
            tile(Icons.account_balance_wallet, 'المالية', '/director/finance'),
            tile(Icons.trending_up, 'المستويات', '/director/levels'),
            tile(Icons.visibility, 'المتابعة التعليمية', '/director/supervision'),
            tile(Icons.bar_chart, 'التقارير', '/director/reports'),
            tile(Icons.campaign, 'الإعلانات', '/director/announcements'),
            tile(Icons.manage_accounts, 'الحسابات', '/director/accounts'),
            const SizedBox(height: DesignTokens.space12),
            OutlinedButton.icon(
              onPressed: () => ref.read(authGatewayProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }
}
