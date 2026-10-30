import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/student_workspace.dart';
import 'package:quran_center/features/student/student_data.dart';
import 'package:quran_center/features/student/widgets/student_scaffold.dart';

String taskRangeText(LearningTask t) {
  final name = surahByNumber(t.surah)?.name ?? 'سورة ${t.surah}';
  return t.startAyah == t.endAyah
      ? '$name: ${t.startAyah}'
      : '$name: ${t.startAyah}–${t.endAyah}';
}

/// One task. The student can start it and report practice, but a task is
/// completed only when the teacher verifies it, and the screen says so.
class StudentTaskDetailScreen extends ConsumerWidget {
  const StudentTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  Future<void> _act(
      BuildContext context,
      WidgetRef ref,
      String success,
      Future<void> Function(
              StudentWorkspace ws, String centerId, String studentId)
          action) async {
    final messenger = ScaffoldMessenger.of(context);
    final profile = ref.read(currentSessionProvider).profile!;
    try {
      await action(ref.read(studentWorkspaceProvider), profile.centerId,
          profile.studentId!);
      ref.invalidate(studentDataProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(success), backgroundColor: DesignTokens.success));
    } on StudentActionException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: DesignTokens.error));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('تعذر تنفيذ الإجراء. تحقق من اتصالك وحاول مرة أخرى.'),
            backgroundColor: DesignTokens.error));
    }
  }

  Future<void> _reportPractice(BuildContext context, WidgetRef ref) async {
    final reflection = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أتممتُ التدريب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سنسجّل أنك تدربت على هذه المهمة. يبقى على معلمك أن يسمع منك ويعتمدها.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                controller: reflection,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'ملاحظة عن تدريبك (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('رجوع')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('تسجيل')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _act(
        context,
        ref,
        'تم تسجيل تدريبك. بانتظار اعتماد معلمك.',
        (ws, c, s) =>
            ws.reportPractice(c, s, taskId, reflection: reflection.text));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StudentScaffold(
      title: 'تفاصيل المهمة',
      navIndex: 1,
      builder: (context, ref, d) {
        final t = d.tasks.where((x) => x.taskId == taskId).firstOrNull;
        if (t == null) {
          return ListView(children: const [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space24),
              child: EmptyState('المهمة غير موجودة'),
            ),
          ]);
        }
        final v = t.teacherVerification;
        final claim = t.selfReportedPractice;
        final open = t.status != TaskStatus.completed &&
            t.status != TaskStatus.cancelled;

        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            Text(taskTypeLabel(t.taskType),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: DesignTokens.space4),
            Text(taskRangeText(t), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: DesignTokens.space16),
            Card(
              child: Column(children: [
                _row('الحالة',
                    '${taskStatusLabel(t.status)}${t.isOverdue ? ' • متأخرة' : ''}'),
                const Divider(height: 1),
                _row('موعد التسليم', DateFormat.yMMMMd('ar').format(t.dueDate)),
                if (t.teacherInstructions.isNotEmpty) ...[
                  const Divider(height: 1),
                  _row('تعليمات المعلم', t.teacherInstructions),
                ],
              ]),
            ),
            if (claim != null) ...[
              const SizedBox(height: DesignTokens.space12),
              Text(
                'سجّلتَ أنك تدربت في ${DateFormat.yMMMd('ar').format(claim.reportedAt)}'
                '${claim.reflection == null ? '' : ' — ${claim.reflection}'}',
                style: const TextStyle(color: DesignTokens.secondaryText),
              ),
            ],
            if (v != null) ...[
              const SizedBox(height: DesignTokens.space12),
              Text(
                v.result == verificationPassed
                    ? 'اعتمد المعلم إنجازك ✓'
                    : 'طلب المعلم إعادة المحاولة',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: v.result == verificationPassed
                        ? DesignTokens.success
                        : DesignTokens.warning),
              ),
              if (v.feedback != null) Text(v.feedback!),
            ],
            if (t.status == TaskStatus.practiceReported ||
                t.status == TaskStatus.submittedForReview) ...[
              const SizedBox(height: DesignTokens.space12),
              const Text('بانتظار أن يسمع منك معلمك ويعتمد المهمة.',
                  style: TextStyle(color: DesignTokens.secondaryText)),
            ],
            if (open) ...[
              const SizedBox(height: DesignTokens.space24),
              if (t.status == TaskStatus.upcoming)
                OutlinedButton(
                  onPressed: () => _act(context, ref, 'بدأت المهمة',
                      (ws, c, s) => ws.start(c, s, taskId)),
                  child: const Text('بدأتُ العمل'),
                ),
              if (t.status == TaskStatus.needsReview)
                OutlinedButton(
                  onPressed: () => _act(context, ref, 'بدأت المحاولة من جديد',
                      (ws, c, s) => ws.start(c, s, taskId)),
                  child: const Text('أعيد المحاولة'),
                ),
              if (t.status == TaskStatus.upcoming ||
                  t.status == TaskStatus.inProgress ||
                  t.status == TaskStatus.needsReview) ...[
                const SizedBox(height: DesignTokens.space8),
                FilledButton(
                  onPressed: () => _reportPractice(context, ref),
                  child: const Text('أتممتُ التدريب'),
                ),
              ],
              if (t.status == TaskStatus.practiceReported) ...[
                FilledButton(
                  onPressed: () => _act(context, ref, 'أُرسلت للمراجعة',
                      (ws, c, s) => ws.submitForReview(c, s, taskId)),
                  child: const Text('إرسال للمراجعة'),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(
            vertical: DesignTokens.space12, horizontal: DesignTokens.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: DesignTokens.secondaryText))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
