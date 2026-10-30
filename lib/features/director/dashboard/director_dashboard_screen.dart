import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/dashboard_stats.dart';
import 'package:quran_center/design_system/components/kpi_card.dart';
import 'package:quran_center/design_system/components/section_header.dart';
import 'package:quran_center/features/director/dashboard/dashboard_provider.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';
import 'package:quran_center/features/shared/notifications/notifications_screen.dart';

/// Director overview. Every number comes from the center's own records
/// (see [computeDashboardStats]); nothing here is a placeholder.
class DirectorDashboardScreen extends ConsumerWidget {
  const DirectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName ?? '';
    final stats = ref.watch(dashboardStatsProvider);
    final now = DateTime.now();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
              children: [
                const SizedBox(height: DesignTokens.space16),
                Row(children: [
                  Expanded(
                    child: Text('أهلاً بك، $name',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: DesignTokens.mainText)),
                  ),
                  const NotificationBell(route: '/director/notifications'),
                ]),
                const SizedBox(height: DesignTokens.space4),
                Text(DateFormat.yMMMMEEEEd('ar').format(now),
                    style: const TextStyle(
                        fontSize: 14, color: DesignTokens.secondaryText)),
                const SizedBox(height: DesignTokens.space24),
                stats.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(DesignTokens.space40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => _ErrorBox(
                    onRetry: () => ref.invalidate(dashboardStatsProvider),
                  ),
                  data: (s) => _Content(stats: s),
                ),
                const SectionHeader(title: 'إجراءات سريعة'),
                const _QuickActions(),
                const SizedBox(height: DesignTokens.space40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 0),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final att = stats.weekAttendance;
    final rate = att.rate;
    final isNewCenter = stats.activeStudents == 0 &&
        stats.activeTeachers == 0 &&
        stats.activeCircles == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewCenter)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: DesignTokens.space16),
            padding: const EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: DesignTokens.softMint,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            ),
            child: const Text(
              'لم تُضف بيانات بعد. ابدأ بإضافة معلم وحلقة وطلاب من الإجراءات السريعة أدناه.',
              style: TextStyle(height: 1.6),
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: DesignTokens.space16,
          mainAxisSpacing: DesignTokens.space16,
          children: [
            KpiCard(
              value: '${stats.activeStudents}',
              label: 'طلاب منتظمون',
              icon: Icons.people_outline,
              onTap: () => context.go('/director/students'),
            ),
            KpiCard(
              value: '${stats.activeTeachers}',
              label: 'معلمون نشطون',
              icon: Icons.person_outline,
              color: DesignTokens.informational,
              onTap: () => context.go('/director/teachers'),
            ),
            KpiCard(
              value: '${stats.activeCircles}',
              label: 'حلقات نشطة',
              icon: Icons.school_outlined,
              color: DesignTokens.success,
              onTap: () => context.go('/director/circles'),
            ),
            KpiCard(
              value: '${stats.todaySessions}',
              label: 'جلسات اليوم',
              icon: Icons.today,
              color: DesignTokens.warning,
              onTap: () => context.push('/director/schedules'),
            ),
          ],
        ),
        const SectionHeader(title: 'جلسات اليوم'),
        Row(
          children: [
            _Chip('مجدولة', stats.todayScheduled, DesignTokens.informational),
            _Chip('جارية', stats.todayInProgress, DesignTokens.warning),
            _Chip('منجزة', stats.todayCompleted, DesignTokens.success),
            _Chip('ملغاة', stats.todayCancelled, DesignTokens.error),
          ],
        ),
        const SectionHeader(title: 'الحضور', subtitle: 'آخر 7 أيام'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.borders),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (att.recorded == 0)
                const Text('لا توجد سجلات حضور خلال آخر 7 أيام.')
              else ...[
                Text(
                  rate == null
                      ? 'نسبة الحضور: —'
                      : 'نسبة الحضور: ${(rate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DesignTokens.space8),
                Text(
                  'حاضر ${att.present} • متأخر ${att.late} • غائب ${att.absent} • معذور ${att.excused}',
                  style: const TextStyle(color: DesignTokens.secondaryText),
                ),
              ],
              const SizedBox(height: DesignTokens.space8),
              const Text(
                'النسبة = (حاضر + متأخر) ÷ (حاضر + متأخر + غائب). لا يدخل المعذورون '
                'في المقام، ولا يُعدّ السجل المفقود غيابًا.',
                style: TextStyle(
                    fontSize: 12, color: DesignTokens.secondaryText, height: 1.5),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/director/attendance'),
                  child: const Text('عرض سجلات الحضور'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: DesignTokens.space8),
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.borders),
          ),
          child: Column(
            children: [
              Text('$value',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DesignTokens.space4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
            const SizedBox(height: DesignTokens.space12),
            const Text('تعذر تحميل بيانات اللوحة.'),
            const SizedBox(height: DesignTokens.space12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, String)>[
      ('إضافة طالب', Icons.person_add, '/director/students/add'),
      ('إضافة معلم', Icons.person_add_alt, '/director/teachers/add'),
      ('إنشاء حلقة', Icons.add_box, '/director/circles/add'),
      ('تعيين طالب لحلقة', Icons.assignment_ind, '/director/enrollments/assign'),
      ('إدارة الجدول', Icons.schedule, '/director/schedules'),
      ('سجلات الحضور', Icons.fact_check, '/director/attendance'),
    ];
    return Wrap(
      spacing: DesignTokens.space12,
      runSpacing: DesignTokens.space12,
      children: [
        for (final (label, icon, route) in actions)
          ActionChip(
            avatar: Icon(icon, size: 18, color: DesignTokens.primaryDarkGreen),
            label: Text(label),
            onPressed: () => context.push(route),
          ),
      ],
    );
  }
}
