import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/task_service.dart';

/// Assigns a task (new memorization, revision, recitation) to a student.
class NewTaskScreen extends ConsumerStatefulWidget {
  const NewTaskScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  TaskType _type = TaskType.newMemorization;
  int? _surah;
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _instructions = TextEditingController();
  String? _priority;
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  String? _surahError;
  String? _rangeError;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  // Fixed for this form: a retried save rewrites the same task.
  final String _taskId = 'task_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final start = int.tryParse(_start.text.trim());
    final end = int.tryParse(_end.text.trim());
    String? surahError;
    String? rangeError;
    if (_surah == null) {
      surahError = 'اختر السورة';
    } else if (start == null || end == null) {
      rangeError = 'أدخل رقمي آية البداية والنهاية';
    } else {
      rangeError = validateAyahRange(_surah!, start, end);
    }
    setState(() {
      _surahError = surahError;
      _rangeError = rangeError;
      _error = null;
    });
    if (surahError != null || rangeError != null) return;

    setState(() => _saving = true);
    try {
      await ref.read(taskServiceProvider).assign(
            centerId: ref.read(centerIdProvider),
            teacherId: ref.read(actorProvider).id,
            studentId: widget.studentId,
            taskId: _taskId,
            type: _type,
            surah: _surah!,
            startAyah: start!,
            endAyah: end!,
            dueDate: _due,
            instructions: _instructions.text,
            priority: _priority,
          );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('تم إسناد المهمة'), backgroundColor: DesignTokens.success));
      context.pop(true);
    } on TaskException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ المهمة. حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah == null ? null : surahByNumber(_surah!);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('مهمة جديدة'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            DropdownButtonFormField<TaskType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'نوع المهمة'),
              items: [
                for (final t in TaskType.values)
                  DropdownMenuItem(value: t, child: Text(taskTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: DesignTokens.space16),
            DropdownButtonFormField<int>(
              value: _surah,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'السورة *', errorText: _surahError),
              items: [
                for (final s in surahs)
                  DropdownMenuItem(value: s.number, child: Text('${s.number}. ${s.name}')),
              ],
              onChanged: (v) => setState(() => _surah = v),
            ),
            const SizedBox(height: DesignTokens.space12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'من آية *', errorText: _rangeError),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: TextField(
                    controller: _end,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'إلى آية *'),
                  ),
                ),
              ],
            ),
            if (surah != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space4),
                child: Text('عدد آيات ${surah.name}: ${surah.ayahCount}',
                    style: const TextStyle(fontSize: 12, color: DesignTokens.secondaryText)),
              ),
            const SizedBox(height: DesignTokens.space16),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _due = d);
              },
              icon: const Icon(Icons.event),
              label: Text('موعد التسليم: ${DateFormat.yMMMd('ar').format(_due)}'),
            ),
            const SizedBox(height: DesignTokens.space16),
            DropdownButtonFormField<String?>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'الأولوية (اختياري)'),
              items: const [
                DropdownMenuItem(value: null, child: Text('بدون')),
                DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                DropdownMenuItem(value: 'high', child: Text('مرتفعة')),
              ],
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: DesignTokens.space16),
            TextField(
              controller: _instructions,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'تعليمات للطالب (اختياري)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space16),
                child: Text(_error!, style: const TextStyle(color: DesignTokens.error)),
              ),
            const SizedBox(height: DesignTokens.space24),
            SizedBox(
              height: DesignTokens.buttonHeight,
              child: FilledButton(
                onPressed: (_saving || _saved) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إسناد المهمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
