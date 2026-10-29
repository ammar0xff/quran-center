import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/audit_log.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/repositories/attendance_repository.dart';

String attendanceStatusLabel(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return 'حاضر';
    case AttendanceStatus.absent:
      return 'غائب';
    case AttendanceStatus.late:
      return 'متأخر';
    case AttendanceStatus.excused:
      return 'معذور';
  }
}

Color attendanceStatusColor(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return DesignTokens.success;
    case AttendanceStatus.absent:
      return DesignTokens.error;
    case AttendanceStatus.late:
      return DesignTokens.warning;
    case AttendanceStatus.excused:
      return DesignTokens.informational;
  }
}

IconData attendanceStatusIcon(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return Icons.check_circle;
    case AttendanceStatus.absent:
      return Icons.cancel;
    case AttendanceStatus.late:
      return Icons.schedule;
    case AttendanceStatus.excused:
      return Icons.info;
  }
}

/// Director attendance administration: summary, status filter, record list,
/// correction workflow (reason required, original preserved, audited) and
/// access to a record's correction history.
class AttendanceAdministrationScreen extends ConsumerStatefulWidget {
  const AttendanceAdministrationScreen({super.key});

  @override
  ConsumerState<AttendanceAdministrationScreen> createState() =>
      _AttendanceAdministrationScreenState();
}

class _AttendanceAdministrationScreenState
    extends ConsumerState<AttendanceAdministrationScreen> {
  List<Attendance> _records = [];
  Map<String, String> _studentNames = {};
  AttendanceStatus? _statusFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records =
          await ref.read(attendanceRepositoryProvider).getByCenter('center-1');
      final students =
          await ref.read(studentRepositoryProvider).getStudentsByCenter('center-1');
      if (!mounted) return;
      setState(() {
        _records = records;
        _studentNames = {for (final s in students) s.studentId: s.displayName};
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل سجلات الحضور';
      });
    }
  }

  List<Attendance> get _visible => _records
      .where((r) => _statusFilter == null || r.status == _statusFilter)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _openCorrection(Attendance record) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _CorrectionDialog(
        record: record,
        studentName: _studentNames[record.studentId] ?? record.studentId,
      ),
    );
    if (done == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تصحيح الحضور وتسجيل التغيير'),
        backgroundColor: DesignTokens.success,
      ));
    }
  }

  Future<void> _openHistory(Attendance record) async {
    final logs = await ref
        .read(auditRepositoryProvider)
        .getForEntity('attendance', record.attendanceId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _HistorySheet(logs: logs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = AttendanceSummary.from(_records);
    final items = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('إدارة الحضور'), centerTitle: false),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: DesignTokens.space12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(DesignTokens.space20),
                    children: [
                      _SummaryCard(summary: summary),
                      const SizedBox(height: DesignTokens.space16),
                      Wrap(
                        spacing: DesignTokens.space8,
                        children: [
                          ChoiceChip(
                            label: const Text('الكل'),
                            selected: _statusFilter == null,
                            onSelected: (_) =>
                                setState(() => _statusFilter = null),
                          ),
                          for (final s in AttendanceStatus.values)
                            ChoiceChip(
                              label: Text(attendanceStatusLabel(s)),
                              selected: _statusFilter == s,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = s),
                            ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(DesignTokens.space32),
                          child: Center(
                            child: Text(
                              _records.isEmpty
                                  ? 'لا توجد سجلات حضور بعد'
                                  : 'لا توجد سجلات مطابقة',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      else
                        for (final r in items)
                          _RecordTile(
                            record: r,
                            studentName: _studentNames[r.studentId] ?? r.studentId,
                            onCorrect: () => _openCorrection(r),
                            onHistory: () => _openHistory(r),
                          ),
                    ],
                  ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.rate;
    Widget cell(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: DesignTokens.space4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cell('حاضر', summary.present, DesignTokens.success),
              cell('غائب', summary.absent, DesignTokens.error),
              cell('متأخر', summary.late, DesignTokens.warning),
              cell('معذور', summary.excused, DesignTokens.informational),
            ],
          ),
          const Divider(height: DesignTokens.space24),
          Text(
            rate == null
                ? 'نسبة الحضور: —'
                : 'نسبة الحضور: ${(rate * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DesignTokens.space4),
          const Text(
            'النسبة = (حاضر + متأخر) ÷ (حاضر + متأخر + غائب). '
            'لا يدخل المعذورون في المقام، ولا يُعدّ السجل المفقود غيابًا.',
            style: TextStyle(
                fontSize: 12, color: DesignTokens.secondaryText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.studentName,
    required this.onCorrect,
    required this.onHistory,
  });

  final Attendance record;
  final String studentName;
  final VoidCallback onCorrect;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final color = attendanceStatusColor(record.status);
    final corrected = record.correctionMetadata != null;
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: ListTile(
        leading: Icon(attendanceStatusIcon(record.status), color: color),
        title: Text(studentName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Wrap(
          spacing: DesignTokens.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Status is shown as text + icon, never by color alone.
            Text(attendanceStatusLabel(record.status),
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text(DateFormat.yMd('ar').format(record.updatedAt),
                style: const TextStyle(
                    fontSize: 12, color: DesignTokens.secondaryText)),
            if (corrected)
              InkWell(
                onTap: onHistory,
                child: const Text('مصحّح • السجل',
                    style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.informational,
                        decoration: TextDecoration.underline)),
              ),
          ],
        ),
        trailing: TextButton(onPressed: onCorrect, child: const Text('تصحيح')),
      ),
    );
  }
}

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog({required this.record, required this.studentName});
  final Attendance record;
  final String studentName;

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  late AttendanceStatus _status = widget.record.status;
  final _reason = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = validateCorrection(
      current: widget.record.status,
      requested: _status,
      reason: _reason.text,
    );
    if (problem != null) {
      setState(() => _error = problem == CorrectionError.reasonRequired
          ? 'سبب التصحيح مطلوب'
          : 'اختر حالة مختلفة عن الحالة الحالية');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actor = ref.read(actorProvider);
      await ref.read(attendanceRepositoryProvider).correct(
            sessionId: widget.record.sessionId,
            studentId: widget.record.studentId,
            newStatus: _status,
            actorId: actor.id,
            actorRole: actor.role,
            reason: _reason.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on AttendanceCorrectionException catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ التصحيح. حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تصحيح الحضور'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: DesignTokens.space4),
              Text('الحالة الحالية: ${attendanceStatusLabel(widget.record.status)}',
                  style: const TextStyle(color: DesignTokens.secondaryText)),
              const SizedBox(height: DesignTokens.space16),
              DropdownButtonFormField<AttendanceStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'الحالة الجديدة'),
                items: [
                  for (final s in AttendanceStatus.values)
                    DropdownMenuItem(
                        value: s, child: Text(attendanceStatusLabel(s))),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب التصحيح *'),
              ),
              const SizedBox(height: DesignTokens.space8),
              const Text(
                'تُحفظ الحالة الأصلية ويُسجَّل التصحيح في سجل التدقيق.',
                style: TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
              ),
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.space8),
                Text(_error!,
                    style: const TextStyle(color: DesignTokens.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: const Text('حفظ التصحيح'),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.logs});
  final List<AuditLog> logs;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سجل التصحيحات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: DesignTokens.space12),
            if (logs.isEmpty)
              const Text('لا توجد تصحيحات مسجلة')
            else
              for (final l in logs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${_label(l.previousValue?['status'])} ← ${_label(l.newValue?['status'])}'),
                  subtitle: Text(
                      '${l.reason ?? ''} • ${DateFormat.yMd('ar').add_jm().format(l.createdAt)}'),
                ),
          ],
        ),
      ),
    );
  }

  String _label(dynamic status) {
    if (status is! String) return '—';
    try {
      return attendanceStatusLabel(AttendanceStatusJson.fromJson(status));
    } catch (_) {
      return status;
    }
  }
}
