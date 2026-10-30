import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/day_path.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/shared/notifications/notifications_screen.dart';
import 'package:quran_center/features/student/tasks/student_task_detail_screen.dart'
    show taskRangeText;
import 'package:quran_center/features/student/widgets/student_scaffold.dart';
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart'
    show assessmentTypeLabel;

/// Student home: the level and the streak up top, then what to do today as a
/// path, the next class, and the last wird heard. Only real records.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName ?? '';
    return StudentScaffold(
      title: 'الرئيسية',
      navIndex: 0,
      showAppBar: false,
      edgeToEdge: true,
      builder: (context, ref, d) {
        final now = DateTime.now();
        final level = computeLevel(d.feedback);
        final next = d.nextSession(now);
        final last = d.feedback.firstOrNull;
        final open = d.openTasks.take(4).toList();

        return ListView(
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
                          ]),
                    ),
                    const NotificationBell(
                        route: '/student/notifications', onDark: true),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    HeroStat(
                      label: 'مستواك',
                      leading: LevelBadge(level: level, size: 46, onDark: true),
                      value: Text(level.label ?? 'لم يبدأ بعد',
                          style: const TextStyle(fontSize: 16)),
                      onTap: () => context.go('/student/feedback'),
                    ),
                    const SizedBox(width: 12),
                    HeroStat(
                      label: 'حضور متتالٍ',
                      leading: Rosette(
                        size: 46,
                        color: DesignTokens.gold,
                        child: Text('${d.streak}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ),
                      value: Text(
                          d.streak == 0 ? 'ابدأ اليوم' : '${d.streak} جلسات',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('مسار اليوم'),
                  if (open.isEmpty)
                    _Note(d.tasks.isEmpty
                        ? 'لا توجد مهام بعد. سيسندها إليك معلمك.'
                        : 'أنجزتَ كل مهامك الحالية. أحسنت!')
                  else
                    DayPath(steps: [
                      for (var i = 0; i < open.length; i++)
                        _step(context, open[i], i == 0),
                    ]),
                  const SectionTitle('الحصة القادمة'),
                  if (d.circle == null)
                    const _Note('لم تُسجَّل في حلقة بعد. تواصل مع إدارة الدار.')
                  else if (next == null)
                    _Note('لا توجد حصص قادمة في ${d.circle!.name}.')
                  else
                    Card(
                      child: ListTile(
                        leading: _DateTile(date: next.date),
                        title: Text(d.circle!.name),
                        subtitle: Text(
                            '${DateFormat.MMMEd('ar').format(next.date)} • ${next.startTime}–${next.endTime} • ${circleModeLabel(next.locationOrMode)}'),
                        onTap: () => context.go('/student/schedule'),
                      ),
                    ),
                  const SectionTitle('تقدمك'),
                  Row(children: [
                    _Count(
                        label: 'مهام معتمدة من المعلم',
                        value: d.completedTasks.length,
                        color: DesignTokens.success),
                    const SizedBox(width: 10),
                    _Count(
                        label: 'مهام مفتوحة',
                        value: d.openTasks.length,
                        color: DesignTokens.informational,
                        onTap: () => context.go('/student/tasks')),
                  ]),
                  const SectionTitle('آخر ورد سمّعته'),
                  if (last == null)
                    const _Note('لا توجد ملاحظات بعد.')
                  else
                    _LastWird(
                        record: last,
                        onTap: () => context.go('/student/feedback')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  PathStep _step(BuildContext context, LearningTask t, bool first) => PathStep(
        title: '${taskTypeLabel(t.taskType)} • ${taskRangeText(t)}',
        subtitle: '${taskStatusLabel(t.status)}'
            '${t.isOverdue ? ' • متأخرة' : ''} • الموعد ${DateFormat.MMMEd('ar').format(t.dueDate)}',
        state: t.isOverdue
            ? PathState.late
            : first
                ? PathState.current
                : PathState.upcoming,
        actionLabel: first
            ? (t.status == TaskStatus.upcoming ? 'ابدأ المهمة' : 'تابع المهمة')
            : null,
        onTap: () => context.push('/student/tasks/${t.taskId}'),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                color: DesignTokens.secondaryText, height: 1.5)),
      );
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date});
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

class _Count extends StatelessWidget {
  const _Count(
      {required this.label,
      required this.value,
      required this.color,
      this.onTap});
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1.1)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: DesignTokens.secondaryText,
                            height: 1.4)),
                  ]),
            ),
          ),
        ),
      );
}

/// "Last read" of this app: the last wird heard for the student, with the
/// surah name in Amiri on a gold rosette.
class _LastWird extends StatelessWidget {
  const _LastWird({required this.record, required this.onTap});
  final dynamic record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final surah = surahByNumber(r.surah);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Rosette(
              size: 56,
              color: DesignTokens.gold,
              child: Text('${r.surah}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surah?.name ?? '',
                        style: const TextStyle(
                            fontFamily: DesignTokens.nameFont,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6420),
                            height: 1.3)),
                    Text(
                        '${assessmentTypeLabel(r.assessmentType)} • الآيات ${r.startAyah}–${r.endAyah}'
                        '${r.studentVisibleFeedback == null ? '' : '\n${r.studentVisibleFeedback}'}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: DesignTokens.secondaryText,
                            height: 1.5)),
                  ]),
            ),
            if (r.grade != null) GradeChip(r.grade as WirdGrade, large: true),
          ]),
        ),
      ),
    );
  }
}
