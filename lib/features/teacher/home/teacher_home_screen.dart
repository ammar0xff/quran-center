import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/shared/notifications/notifications_screen.dart';
import 'package:quran_center/features/teacher/home/teacher_home_data.dart';
import 'package:quran_center/features/teacher/widgets/sync_status_bar.dart';
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

/// Teacher home: a header with her numbers, then today's sessions in time
/// order (the one running or next is highlighted) and what needs her attention.
/// Every number comes from records scoped to this teacher.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName ?? '';
    final async = ref.watch(teacherHomeProvider);
    final data = async.valueOrNull;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: RefreshIndicator(
          onRefresh: () async => ref.refresh(teacherHomeProvider.future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
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
                              Text(
                                  DateFormat.yMMMMEEEEd('ar')
                                      .format(DateTime.now()),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white
                                          .withValues(alpha: 0.75))),
                            ]),
                      ),
                      const NotificationBell(
                          route: '/teacher/notifications', onDark: true),
                    ]),
                    if (data != null) ...[
                      const SizedBox(height: 18),
                      Row(children: [
                        HeroStat(
                          label: 'طلابي',
                          leading: Rosette(
                              size: 44,
                              color: DesignTokens.gold,
                              child: const Icon(Icons.people_alt_rounded,
                                  color: Colors.white, size: 20)),
                          value: Text('${data.studentCount}'),
                          onTap: () => context.go('/teacher/students'),
                        ),
                        const SizedBox(width: 12),
                        HeroStat(
                          label: 'حلقاتي',
                          leading: Rosette(
                              size: 44,
                              color: DesignTokens.gold,
                              child: const Icon(Icons.school_rounded,
                                  color: Colors.white, size: 20)),
                          value: Text('${data.circles.length}'),
                          onTap: () => context.go('/teacher/circles'),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SyncStatusBar(),
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
                              onPressed: () =>
                                  ref.invalidate(teacherHomeProvider),
                              child: const Text('إعادة المحاولة')),
                        ]),
                      ),
                      data: (d) => _Content(data: d),
                    ),
                  ],
                ),
              ),
            ],
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
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: DesignTokens.softMint,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
        child: const Text(
            'لم تُسند إليك حلقات أو طلاب بعد. تواصل مع إدارة الدار.',
            style: TextStyle(height: 1.6)),
      );
    }
    // The running session, else the first not yet started.
    final focusId = (data.todaySessions
                .where((s) => s.status == SessionStatus.inProgress)
                .firstOrNull ??
            data.todaySessions
                .where((s) => s.status == SessionStatus.scheduled)
                .firstOrNull)
        ?.scheduleId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('جلسات اليوم'),
        if (data.todaySessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
            child: Text('لا توجد جلسات اليوم.',
                style: TextStyle(color: DesignTokens.secondaryText)),
          )
        else
          for (final s in data.todaySessions)
            _SessionCard(
              session: s,
              circleName: data.circleNames[s.circleId] ?? 'حلقة',
              focus: s.scheduleId == focusId,
            ),
        const SectionTitle('المتابعة'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('مهام بانتظار تحققك'),
                subtitle:
                    const Text('أبلغ الطالب أنه تدرّب عليها ولم تعتمدها بعد'),
                trailing:
                    _Number(data.awaitingVerification, DesignTokens.warning),
                onTap: () => context.go('/teacher/students'),
              ),
              const Divider(),
              ListTile(
                title: const Text('مهام متأخرة'),
                subtitle: const Text('تجاوزت موعد تسليمها ولم تكتمل'),
                trailing: _Number(data.overdueTasks, DesignTokens.error),
                onTap: () => context.go('/teacher/students'),
              ),
            ],
          ),
        ),
        if (data.upcoming.isNotEmpty) ...[
          const SectionTitle('الجلسات القادمة'),
          for (final s in data.upcoming)
            Card(
              child: ListTile(
                leading: _TimeTile(date: s.date),
                title: Text(data.circleNames[s.circleId] ?? 'حلقة'),
                subtitle: Text(
                    '${DateFormat.MMMEd('ar').format(s.date)} • ${s.startTime}–${s.endTime}'),
              ),
            ),
        ],
      ],
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.n, this.color);
  final int n;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              (n == 0 ? DesignTokens.success : color).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$n',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: n == 0 ? DesignTokens.success : color)),
      );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          color: DesignTokens.softMint,
          borderRadius: BorderRadius.circular(12)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat.MMM('ar').format(date),
              style: const TextStyle(
                  fontSize: 11,
                  color: DesignTokens.primaryDarkGreen,
                  fontWeight: FontWeight.w600)),
          Text('${date.day}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.primaryDarkGreen)),
        ]),
      ));
}

/// One session as a row of the day: its time, the circle, the state. The one
/// to work on now is filled emerald with an action.
class _SessionCard extends StatelessWidget {
  const _SessionCard(
      {required this.session, required this.circleName, required this.focus});
  final Schedule session;
  final String circleName;
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final open = session.status != SessionStatus.cancelled;
    final status = sessionStatusLabel(session.status);
    final statusColor = switch (session.status) {
      SessionStatus.inProgress => DesignTokens.warning,
      SessionStatus.completed => DesignTokens.success,
      SessionStatus.cancelled => DesignTokens.error,
      SessionStatus.scheduled => DesignTokens.informational,
    };
    void go() => context.push('/teacher/sessions/${session.scheduleId}');

    if (focus) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: DesignTokens.primaryDarkGreen,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          onTap: go,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(circleName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  Text(status,
                      style: const TextStyle(
                          color: Color(0xFFE9CF93),
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text(
                    '${session.startTime}–${session.endTime} • ${circleModeLabel(session.locationOrMode)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: go,
                    child: Text(session.status == SessionStatus.inProgress
                        ? 'تابع الجلسة'
                        : 'افتح الجلسة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: DesignTokens.softMint,
              borderRadius: BorderRadius.circular(12)),
          child: Text(session.startTime,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: DesignTokens.primaryDarkGreen)),
        ),
        title: Text(circleName),
        subtitle: Wrap(
          spacing: 8,
          children: [
            Text('${session.startTime}–${session.endTime}'),
            Text(circleModeLabel(session.locationOrMode)),
            Text(status,
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: statusColor)),
          ],
        ),
        trailing: open ? const Icon(Icons.chevron_left_rounded) : null,
        onTap: open ? go : null,
      ),
    );
  }
}
