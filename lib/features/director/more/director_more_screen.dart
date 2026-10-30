import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Sections without a tab of their own, plus the account menu.
class DirectorMoreScreen extends ConsumerWidget {
  const DirectorMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName;

    Widget tile(IconData icon, String title, String route) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: DesignTokens.softMint,
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: DesignTokens.primaryDarkGreen, size: 22),
            ),
            title: Text(title),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => context.push(route),
          ),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('المزيد'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            ProfileBanner(name: name ?? '', subtitle: 'مديرة الدار'),
            const SectionTitle('التعليم'),
            tile(Icons.schedule_rounded, 'إدارة الجدول', '/director/schedules'),
            tile(Icons.fact_check_rounded, 'إدارة الحضور',
                '/director/attendance'),
            tile(Icons.assignment_ind_rounded, 'تعيين طالب لحلقة',
                '/director/enrollments/assign'),
            tile(Icons.trending_up_rounded, 'المستويات', '/director/levels'),
            tile(Icons.visibility_rounded, 'المتابعة التعليمية',
                '/director/supervision'),
            const SectionTitle('الإدارة'),
            tile(Icons.account_balance_wallet_rounded, 'المالية',
                '/director/finance'),
            tile(Icons.bar_chart_rounded, 'التقارير', '/director/reports'),
            tile(
                Icons.campaign_rounded, 'الإعلانات', '/director/announcements'),
            tile(Icons.manage_accounts_rounded, 'الحسابات',
                '/director/accounts'),
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
