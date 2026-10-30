import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/dashboard_stats.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
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
        body: RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHero(
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('السلام عليكم ورحمة الله',
                              style: TextStyle(
                                  fontFamily: DesignTokens.nameFont,
                                  fontSize: 18,
                                  color: Color(0xFFE9CF93))),
                          const SizedBox(height: 2),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.25)),
                          const SizedBox(height: 2),
                          Text(DateFormat.yMMMMEEEEd('ar').format(now),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.75))),
                        ]),
                  ),
                  const NotificationBell(
                      route: '/director/notifications', onDark: true),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
            ],
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
        Row(children: [
          Expanded(
            child: KpiCard(
              value: '${stats.activeStudents}',
              label: 'طلاب منتظمون',
              icon: Icons.people_alt_rounded,
              onTap: () => context.go('/director/students'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: KpiCard(
              value: '${stats.activeTeachers}',
              label: 'معلمون نشطون',
              icon: Icons.person_rounded,
              color: DesignTokens.informational,
              onTap: () => context.go('/director/teachers'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: KpiCard(
              value: '${stats.activeCircles}',
              label: 'حلقات نشطة',
              icon: Icons.school_rounded,
              color: DesignTokens.leaf,
              onTap: () => context.go('/director/circles'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: KpiCard(
              value: '${stats.todaySessions}',
              label: 'جلسات اليوم',
              icon: Icons.today_rounded,
              color: DesignTokens.gold,
              onTap: () => context.push('/director/schedules'),
            ),
          ),
        ]),
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
            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
            border: Border.all(color: DesignTokens.borders, width: 1.5),
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
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.primaryDarkGreen),
                ),
                if (rate != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: rate.clamp(0.0, 1.0).toDouble()),
                  ),
                ],
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
                    fontSize: 12,
                    color: DesignTokens.secondaryText,
                    height: 1.5),
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
            border: Border.all(color: DesignTokens.borders, width: 1.5),
          ),
          child: Column(
            children: [
              Text('$value',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
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
            const Icon(Icons.error_outline,
                size: 48, color: DesignTokens.error),
            const SizedBox(height: DesignTokens.space12),
            const Text('تعذر تحميل بيانات اللوحة.'),
            const SizedBox(height: DesignTokens.space12),
            OutlinedButton(
                onPressed: onRetry, child: const Text('إعادة المحاولة')),
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
      (
        'تعيين طالب لحلقة',
        Icons.assignment_ind,
        '/director/enrollments/assign'
      ),
      ('إدارة الجدول', Icons.schedule, '/director/schedules'),
      ('سجلات الحضور', Icons.fact_check, '/director/attendance'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (label, icon, route) in actions)
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => context.push(route),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: DesignTokens.softMint,
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon,
                          size: 24, color: DesignTokens.primaryDarkGreen),
                    ),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
