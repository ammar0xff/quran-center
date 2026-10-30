import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/student/tasks/student_task_detail_screen.dart'
    show taskRangeText;
import 'package:quran_center/features/student/widgets/student_scaffold.dart';
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart'
    show assessmentTypeLabel;

/// Student home: what to work on, the next class, honest progress counts and
/// the latest feedback. Only real records are shown; nothing is invented.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentSessionProvider).profile?.fullName ?? '';
    return StudentScaffold(
      title: 'الرئيسية',
      navIndex: 0,
      showAppBar: false,
      builder: (context, ref, d) {
        final now = DateTime.now();
        final task = d.primaryTask;
        final next = d.nextSession(now);
        final fb = d.latestFeedback;

        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            Text('أهلاً بك، $name',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: DesignTokens.mainText)),
            const SizedBox(height: DesignTokens.space4),
            Text(DateFormat.yMMMMEEEEd('ar').format(now),
                style: const TextStyle(color: DesignTokens.secondaryText)),
            const SizedBox(height: DesignTokens.space20),

            _Section('مهمتك الآن'),
            if (task == null)
              _Note(d.tasks.isEmpty
                  ? 'لا توجد مهام بعد. سيسندها إليك معلمك.'
                  : 'أنجزتَ كل مهامك الحالية. أحسنت!')
            else
              Card(
                child: ListTile(
                  title: Text('${taskTypeLabel(task.taskType)} • ${taskRangeText(task)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${taskStatusLabel(task.status)}'
                    '${task.isOverdue ? ' • متأخرة' : ''} • الموعد ${DateFormat.MMMEd('ar').format(task.dueDate)}',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/student/tasks/${task.taskId}'),
                ),
              ),

            _Section('الحصة القادمة'),
            if (d.circle == null)
              _Note('لم تُسجَّل في حلقة بعد. تواصل مع إدارة الدار.')
            else if (next == null)
              _Note('لا توجد حصص قادمة في ${d.circle!.name}.')
            else
              Card(
                child: ListTile(
                  title: Text(d.circle!.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${DateFormat.MMMEd('ar').format(next.date)} • ${next.startTime}–${next.endTime} • ${circleModeLabel(next.locationOrMode)}'),
                  onTap: () => context.go('/student/schedule'),
                ),
              ),

            _Section('تقدمك'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('مهام معتمدة من المعلم'),
                    trailing: Text('${d.completedTasks.length}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('مهام مفتوحة'),
                    trailing: Text('${d.openTasks.length}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    onTap: () => context.go('/student/tasks'),
                  ),
                ],
              ),
            ),

            _Section('آخر ملاحظة من المعلم'),
            if (fb == null)
              _Note('لا توجد ملاحظات بعد.')
            else
              Card(
                child: ListTile(
                  title: Text(
                      '${assessmentTypeLabel(fb.assessmentType)} • ${DateFormat.MMMd('ar').format(fb.assessedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(fb.studentVisibleFeedback ?? fb.strengths ?? fb.areasForImprovement ?? ''),
                  onTap: () => context.go('/student/feedback'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            top: DesignTokens.space20, bottom: DesignTokens.space8),
        child: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
        child: Text(text, style: const TextStyle(color: DesignTokens.secondaryText)),
      );
}
