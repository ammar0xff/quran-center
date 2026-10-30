import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/features/student/tasks/student_task_detail_screen.dart'
    show taskRangeText;
import 'package:quran_center/features/student/widgets/student_scaffold.dart';

enum _Filter { open, redo, done, all }

/// The student's tasks, filterable. Empty states say which situation applies.
class StudentTasksScreen extends ConsumerStatefulWidget {
  const StudentTasksScreen({super.key});

  @override
  ConsumerState<StudentTasksScreen> createState() => _StudentTasksScreenState();
}

class _StudentTasksScreenState extends ConsumerState<StudentTasksScreen> {
  _Filter _filter = _Filter.open;

  bool _matches(LearningTask t) {
    switch (_filter) {
      case _Filter.open:
        return t.status != TaskStatus.completed && t.status != TaskStatus.cancelled;
      case _Filter.redo:
        return t.status == TaskStatus.needsReview;
      case _Filter.done:
        return t.status == TaskStatus.completed;
      case _Filter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'مهامي',
      navIndex: 1,
      builder: (context, ref, d) {
        final items = d.tasks.where(_matches).toList();
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space16),
          children: [
            Wrap(
              spacing: DesignTokens.space8,
              children: [
                for (final (f, label) in [
                  (_Filter.open, 'المفتوحة'),
                  (_Filter.redo, 'تحتاج إعادة'),
                  (_Filter.done, 'المكتملة'),
                  (_Filter.all, 'الكل'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.space12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(DesignTokens.space24),
                child: Text(
                  d.tasks.isEmpty
                      ? 'لا توجد مهام بعد. سيسندها إليك معلمك.'
                      : _filter == _Filter.open
                          ? 'لا مهام مفتوحة. أنجزتَ كل شيء!'
                          : 'لا توجد مهام في هذا التصنيف.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DesignTokens.secondaryText),
                ),
              ),
            for (final t in items)
              Card(
                child: ListTile(
                  title: Text('${taskTypeLabel(t.taskType)} • ${taskRangeText(t)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${taskStatusLabel(t.status)}'
                    '${t.isOverdue ? ' • متأخرة' : ''} • ${DateFormat.MMMEd('ar').format(t.dueDate)}',
                    style: TextStyle(
                        color: t.isOverdue ? DesignTokens.error : DesignTokens.secondaryText),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/student/tasks/${t.taskId}'),
                ),
              ),
          ],
        );
      },
    );
  }
}
