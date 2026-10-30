import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/design_system/components/kpi_card.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/teacher/home/teacher_home_data.dart';
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

/// Teacher home: today's sessions and a summary of the teacher's own work.
/// Every number comes from records scoped to this teacher.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName ?? '';
    final async = ref.watch(teacherHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(teacherHomeProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
              children: [
                const SizedBox(height: DesignTokens.space16),
                Text('أهلاً بك، $name',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.mainText)),
                const SizedBox(height: DesignTokens.space4),
                Text(DateFormat.yMMMMEEEEd('ar').format(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 14, color: DesignTokens.secondaryText)),
                const SizedBox(height: DesignTokens.space24),
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(DesignTokens.space40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.all(DesignTokens.space24),
                    child: Column(children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: DesignTokens.error),
                      const SizedBox(height: DesignTokens.space12),
                      const Text('تعذر تحميل بياناتك.'),
                      const SizedBox(height: DesignTokens.space12),
                      OutlinedButton(
                          onPressed: () => ref.invalidate(teacherHomeProvider),
                          child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                  data: (d) => _Content(data: d),
                ),
                const SizedBox(height: DesignTokens.space40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 0),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});
  final TeacherHomeData data;

  @override
  Widget build(BuildContext context) {
    if (!data.hasAssignments && data.todaySessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: DesignTokens.softMint,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
        child: const Text(
          'لم تُسند إليك حلقات أو طلاب بعد. تواصل مع إدارة الدار.',
          style: TextStyle(height: 1.6),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: DesignTokens.space16,
          mainAxisSpacing: DesignTokens.space16,
          children: [
            KpiCard(
              value: '${data.studentCount}',
              label: 'طلابي',
              icon: Icons.people_outline,
            ),
            KpiCard(
              value: '${data.circles.length}',
              label: 'حلقاتي',
              icon: Icons.school_outlined,
              color: DesignTokens.success,
              onTap: () => context.go('/teacher/circles'),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space24),
        const Text('جلسات اليوم',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: DesignTokens.space8),
        if (data.todaySessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
            child: Text('لا توجد جلسات اليوم.',
                style: TextStyle(color: DesignTokens.secondaryText)),
          )
        else
          for (final s in data.todaySessions)
            _SessionCard(
                session: s, circleName: data.circleNames[s.circleId] ?? 'حلقة'),
        if (data.upcoming.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.space24),
          const Text('الجلسات القادمة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: DesignTokens.space8),
          for (final s in data.upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(data.circleNames[s.circleId] ?? 'حلقة'),
              subtitle: Text(
                  '${DateFormat.MMMEd('ar').format(s.date)} • ${s.startTime}–${s.endTime}'),
            ),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.circleName});
  final Schedule session;
  final String circleName;

  @override
  Widget build(BuildContext context) {
    final open = session.status != SessionStatus.cancelled;
    final color = switch (session.status) {
      SessionStatus.inProgress => DesignTokens.warning,
      SessionStatus.completed => DesignTokens.success,
      SessionStatus.cancelled => DesignTokens.error,
      SessionStatus.scheduled => DesignTokens.informational,
    };
    return Card(
      child: ListTile(
        title: Text(circleName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space4),
          child: Wrap(
            spacing: DesignTokens.space8,
            children: [
              Text('${session.startTime}–${session.endTime}'),
              Text(circleModeLabel(session.locationOrMode)),
              Text(sessionStatusLabel(session.status),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        trailing: open ? const Icon(Icons.chevron_left) : null,
        onTap: open
            ? () => context.push('/teacher/sessions/${session.scheduleId}')
            : null,
      ),
    );
  }
}
