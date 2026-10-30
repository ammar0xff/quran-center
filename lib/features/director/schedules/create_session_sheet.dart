import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/schedule_conflicts.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

/// Option shown in the circle / teacher pickers.
class PickerOption {
  const PickerOption(this.id, this.label);
  final String id;
  final String label;
}

/// Bottom sheet that creates a [Schedule].
///
/// Validates: required fields, start < end, and teacher/circle conflicts
/// against [existing]. Conflicts are shown and block saving.
class CreateSessionSheet extends StatefulWidget {
  const CreateSessionSheet({
    super.key,
    required this.centerId,
    required this.circles,
    required this.teachers,
    required this.existing,
    required this.onSave,
  });

  final String centerId;
  final List<PickerOption> circles;
  final List<PickerOption> teachers;
  final List<Schedule> existing;
  final Future<void> Function(Schedule schedule) onSave;

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  String? _circleId;
  String? _teacherId;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  String _mode = 'onsite';
  String? _error;
  bool _saving = false;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_circleId == null || _teacherId == null) {
      setState(() => _error = 'اختر الحلقة والمعلم');
      return;
    }
    final start = _fmt(_start);
    final end = _fmt(_end);
    if (!isValidTimeRange(start, end)) {
      setState(() => _error = 'وقت البداية يجب أن يسبق وقت النهاية');
      return;
    }
    final now = DateTime.now();
    final candidate = Schedule(
      scheduleId: 'sch_${now.millisecondsSinceEpoch}',
      centerId: widget.centerId,
      circleId: _circleId!,
      teacherId: _teacherId!,
      date: DateTime(_date.year, _date.month, _date.day),
      startTime: start,
      endTime: end,
      locationOrMode: _mode,
      status: SessionStatus.scheduled,
      createdAt: now,
      updatedAt: now,
    );

    final conflicts = findScheduleConflicts(candidate, widget.existing);
    if (conflicts.isNotEmpty) {
      final lines = conflicts.map((c) {
        final who = c.type == ConflictType.teacher
            ? 'المعلم مشغول'
            : 'الحلقة لديها جلسة';
        return '$who (${c.existing.startTime} - ${c.existing.endTime})';
      }).toSet();
      setState(() => _error = 'يوجد تعارض في الجدول:\n${lines.join('\n')}');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSave(candidate);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر الحفظ. حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: DesignTokens.space20,
          right: DesignTokens.space20,
          top: DesignTokens.space20,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + DesignTokens.space20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إنشاء جلسة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DesignTokens.space16),
              DropdownButtonFormField<String>(
                value: _circleId,
                decoration: const InputDecoration(labelText: 'الحلقة *'),
                items: widget.circles
                    .map((o) =>
                        DropdownMenuItem(value: o.id, child: Text(o.label)))
                    .toList(),
                onChanged: (v) => setState(() => _circleId = v),
              ),
              const SizedBox(height: DesignTokens.space12),
              DropdownButtonFormField<String>(
                value: _teacherId,
                decoration: const InputDecoration(labelText: 'المعلم *'),
                items: widget.teachers
                    .map((o) =>
                        DropdownMenuItem(value: o.id, child: Text(o.label)))
                    .toList(),
                onChanged: (v) => setState(() => _teacherId = v),
              ),
              const SizedBox(height: DesignTokens.space12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التاريخ'),
                subtitle: Text(DateFormat.yMMMMd('ar').format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
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
              const SizedBox(height: DesignTokens.space12),
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
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.space12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    color: DesignTokens.error.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSmall),
                    border: Border.all(
                        color: DesignTokens.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: DesignTokens.error, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.space16),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.buttonHeight,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ الجلسة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
