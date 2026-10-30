import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/circle_validation.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/providers/repositories.dart';

/// Weekday labels in display order (week starts Saturday). Values are ISO
/// weekday numbers: 1 = Monday ... 7 = Sunday.
const _days = <(int, String)>[
  (6, 'السبت'),
  (7, 'الأحد'),
  (1, 'الاثنين'),
  (2, 'الثلاثاء'),
  (3, 'الأربعاء'),
  (4, 'الخميس'),
  (5, 'الجمعة'),
];

/// Director form that creates a circle.
class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _name = TextEditingController();
  final _level = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  final _duration = TextEditingController(text: '60');
  final _description = TextEditingController();

  String _mode = 'onsite';
  String? _teacherId;
  final Set<int> _selectedDays = {};
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  CircleFormErrors _errors = const CircleFormErrors();
  List<Teacher> _teachers = [];
  bool _saving = false;
  bool _saved = false;
  String? _saveError;

  /// Fixed per form so a retried save rewrites the same circle.
  final String _circleId = 'c_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final all = await ref
          .read(teacherRepositoryProvider)
          .getTeachersByCenter(ref.read(centerIdProvider));
      if (!mounted) return;
      setState(() => _teachers =
          all.where((t) => t.status == AccountStatus.active).toList());
    } catch (_) {
      // The teacher is optional; the form stays usable without the list.
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _level, _capacity, _duration, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving || _saved) return;
    final errors = validateCircleForm(
      name: _name.text,
      capacity: _capacity.text,
      duration: _duration.text,
      scheduleDays: _selectedDays,
      start: _fmt(_start),
      end: _fmt(_end),
    );
    setState(() {
      _errors = errors;
      _saveError = null;
    });
    if (errors.hasErrors) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final actor = ref.read(actorProvider);
      final description = _description.text.trim();
      await ref.read(circleRepositoryProvider).createCircle(Circle(
            circleId: _circleId,
            centerId: ref.read(centerIdProvider),
            name: _name.text.trim(),
            description: description.isEmpty ? null : description,
            educationalLevel: _level.text.trim(),
            assignedTeacherId: _teacherId,
            maxCapacity: int.parse(_capacity.text.trim()),
            locationOrMode: _mode,
            weeklySchedule: [
              for (final (d, _) in _days)
                if (_selectedDays.contains(d))
                  CircleWeeklySchedule(
                      dayOfWeek: d, startTime: _fmt(_start), endTime: _fmt(_end)),
            ],
            sessionDurationMinutes: int.parse(_duration.text.trim()),
            status: CircleStatus.active,
            createdBy: actor.id,
            updatedBy: actor.id,
            createdAt: now,
            updatedAt: now,
          ));
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إنشاء الحلقة'),
        backgroundColor: DesignTokens.success,
      ));
      context.go('/director/circles');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'تعذر حفظ الحلقة. البيانات محفوظة في النموذج، حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('إنشاء حلقة'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: 'اسم الحلقة *', errorText: _errors.name),
            ),
            const SizedBox(height: DesignTokens.space16),
            TextField(
              controller: _level,
              decoration: const InputDecoration(labelText: 'المستوى التعليمي'),
            ),
            const SizedBox(height: DesignTokens.space16),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
            ),
            const SizedBox(height: DesignTokens.space16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'السعة القصوى *', errorText: _errors.capacity),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'مدة الجلسة (دقيقة) *',
                        errorText: _errors.duration),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space16),
            DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(labelText: 'المكان / النمط'),
              items: const [
                DropdownMenuItem(value: 'onsite', child: Text('حضوري')),
                DropdownMenuItem(value: 'online', child: Text('عن بعد')),
                DropdownMenuItem(value: 'hybrid', child: Text('مختلط')),
              ],
              onChanged: (v) => setState(() => _mode = v ?? 'onsite'),
            ),
            const SizedBox(height: DesignTokens.space16),
            DropdownButtonFormField<String?>(
              value: _teacherId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المعلم (اختياري)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('بدون معلم الآن')),
                for (final t in _teachers)
                  DropdownMenuItem<String?>(value: t.teacherId, child: Text(t.fullName)),
              ],
              onChanged: (v) => setState(() => _teacherId = v),
            ),
            const SizedBox(height: DesignTokens.space24),
            const Text('الجدول الأسبوعي (اختياري)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: DesignTokens.space8),
            Wrap(
              spacing: DesignTokens.space8,
              children: [
                for (final (d, label) in _days)
                  FilterChip(
                    label: Text(label),
                    selected: _selectedDays.contains(d),
                    onSelected: (on) => setState(
                        () => on ? _selectedDays.add(d) : _selectedDays.remove(d)),
                  ),
              ],
            ),
            if (_selectedDays.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: _start);
                        if (t != null) setState(() => _start = t);
                      },
                      child: Text('البداية ${_fmt(_start)}'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: _end);
                        if (t != null) setState(() => _end = t);
                      },
                      child: Text('النهاية ${_fmt(_end)}'),
                    ),
                  ),
                ],
              ),
            ],
            if (_errors.schedule != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space8),
                child: Text(_errors.schedule!,
                    style: const TextStyle(color: DesignTokens.error)),
              ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space16),
                child: Text(_saveError!,
                    style: const TextStyle(color: DesignTokens.error)),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ الحلقة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
