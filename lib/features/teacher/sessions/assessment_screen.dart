import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/sync_providers.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';

String assessmentTypeLabel(AssessmentType t) {
  switch (t) {
    case AssessmentType.newMemorization:
      return 'ورد الحفظ';
    case AssessmentType.recentRevision:
      return 'مراجعة: ماضي قريب';
    case AssessmentType.longTermRevision:
      return 'مراجعة: ماضي بعيد';
    case AssessmentType.generalRecitation:
      return 'تلاوة عامة';
    case AssessmentType.newAssignment:
      return 'الجديد';
  }
}

/// The wirds a student hears in a visit, in the order they are heard.
const _visitWirds = [
  AssessmentType.newMemorization,
  AssessmentType.recentRevision,
  AssessmentType.longTermRevision,
  AssessmentType.newAssignment,
];

class _WirdEntry {
  bool included = false;
  int? surah;
  final start = TextEditingController();
  final end = TextEditingController();
  WirdGrade? grade;
  String? error;

  void dispose() {
    start.dispose();
    end.dispose();
  }
}

/// One visit of one student: the teacher records whichever of the four wirds
/// were heard (ورد الحفظ، المراجعة القريبة، المراجعة البعيدة) with a mark for each
/// (ممتاز، جيد جدًا، جيد، مقبول، إعادة), and the new portion the student takes
/// (الجديد), which is not marked. The student may sit with a teacher who is not
/// their usual one; the marks join the student's record either way.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.sessionId,
    required this.studentId,
    this.studentName,
  });

  final String sessionId;
  final String studentId;
  final String? studentName;

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  final Map<AssessmentType, _WirdEntry> _entries = {
    for (final t in _visitWirds) t: _WirdEntry(),
  };
  final _feedback = TextEditingController();
  final _private = TextEditingController();
  bool _followUp = false;

  bool _saving = false;
  bool _saved = false;
  bool _discarded = false;
  bool _dirty = false;
  String? _saveError;

  // Fixed for the life of this form, so a retried save never duplicates.
  final String _visitId = 'v_${DateTime.now().microsecondsSinceEpoch}';
  final DateTime _assessedAt = DateTime.now();

  @override
  void dispose() {
    for (final e in _entries.values) {
      e.dispose();
    }
    _feedback.dispose();
    _private.dispose();
    super.dispose();
  }

  String? _validate(AssessmentType type, _WirdEntry e) {
    if (e.surah == null) return 'اختر السورة';
    final start = int.tryParse(e.start.text.trim());
    final end = int.tryParse(e.end.text.trim());
    if (start == null || end == null) return 'أدخل رقمي آية البداية والنهاية';
    final range = validateAyahRange(e.surah!, start, end);
    if (range != null) return range;
    if (type != AssessmentType.newAssignment && e.grade == null)
      return 'اختر التقدير';
    return null;
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final chosen = _entries.entries.where((e) => e.value.included).toList();
    var ok = true;
    for (final e in chosen) {
      e.value.error = _validate(e.key, e.value);
      if (e.value.error != null) ok = false;
    }
    if (chosen.isEmpty) {
      setState(() => _saveError = 'اختر ورد واحدًا على الأقل مما سمعته.');
      return;
    }
    setState(() => _saveError = null);
    if (!ok) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    try {
      final work = ref.read(sessionWorkProvider);
      final centerId = ref.read(centerIdProvider);
      final teacherId = ref.read(actorProvider).id;
      var first = true;
      for (final c in chosen) {
        final e = c.value;
        // The note for the student and the private note belong to the visit;
        // they are stored once, with its first wird.
        await work.saveAssessment(
          label: widget.studentName,
          centerId: centerId,
          teacherId: teacherId,
          sessionId: widget.sessionId,
          studentId: widget.studentId,
          recordId: '${_visitId}_${c.key.name}',
          assessedAt: _assessedAt,
          draft: AssessmentDraft(
            type: c.key,
            grade: c.key == AssessmentType.newAssignment ? null : e.grade,
            visitId: _visitId,
            surah: e.surah!,
            startAyah: int.parse(e.start.text.trim()),
            endAyah: int.parse(e.end.text.trim()),
            requiresFollowUp: _followUp,
            studentVisibleFeedback: first ? _feedback.text : null,
            privateNote: first ? _private.text : null,
          ),
        );
        first = false;
      }
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('تم حفظ التسميع'),
            backgroundColor: DesignTokens.success));
      context.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError =
              'تعذر الحفظ على الجهاز. بياناتك ما زالت في النموذج، حاول مرة أخرى.';
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty && !_entries.values.any((e) => e.included)) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تجاهل التسميع؟'),
          content: const Text('لم يتم حفظ ما أدخلته.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('متابعة التعديل')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('تجاهل')),
          ],
        ),
      ),
    );
    return leave == true;
  }

  Widget _wirdCard(AssessmentType type) {
    final e = _entries[type]!;
    final graded = type != AssessmentType.newAssignment;
    final surah = e.surah == null ? null : surahByNumber(e.surah!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(assessmentTypeLabel(type),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  graded ? 'سمع الطالب هذا الورد' : 'ما سيحفظه الطالب بعد ذلك'),
              value: e.included,
              onChanged: (v) => setState(() {
                e.included = v;
                _dirty = true;
              }),
            ),
            if (e.included) ...[
              DropdownButtonFormField<int>(
                key: ValueKey('surah_${type.name}'),
                value: e.surah,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'السورة *'),
                items: [
                  for (final s in surahs)
                    DropdownMenuItem(
                        value: s.number,
                        child: Text('${s.number}. ${s.name}',
                            style: const TextStyle(
                                fontFamily: DesignTokens.nameFont,
                                fontSize: 19))),
                ],
                onChanged: (v) => setState(() {
                  e.surah = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: DesignTokens.space8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: e.start,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _dirty = true,
                      decoration: InputDecoration(
                          labelText: 'من آية *',
                          errorText: e.error != null && e.surah != null
                              ? e.error
                              : null),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: TextField(
                      controller: e.end,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _dirty = true,
                      decoration: const InputDecoration(labelText: 'إلى آية *'),
                    ),
                  ),
                ],
              ),
              if (surah != null)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.space4),
                  child: Text('عدد آيات ${surah.name}: ${surah.ayahCount}',
                      style: const TextStyle(
                          fontSize: 12, color: DesignTokens.secondaryText)),
                ),
              if (e.surah == null && e.error != null)
                Text(e.error!,
                    style: const TextStyle(color: DesignTokens.error)),
              if (graded) ...[
                const SizedBox(height: DesignTokens.space12),
                const Text('التقدير *',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: DesignTokens.space8,
                  children: [
                    for (final g in WirdGrade.values)
                      ChoiceChip(
                        key: ValueKey('grade_${type.name}_${g.name}'),
                        label: Text(g.label),
                        selectedColor: gradeColor(g).withValues(alpha: 0.18),
                        side: BorderSide(
                            color: e.grade == g
                                ? gradeColor(g)
                                : DesignTokens.bordersStrong,
                            width: 1.5),
                        labelStyle: TextStyle(
                            fontFamily: DesignTokens.uiFont,
                            fontWeight: FontWeight.w700,
                            color: e.grade == g
                                ? Color.lerp(gradeColor(g), Colors.black, 0.3)
                                : DesignTokens.mainText),
                        selected: e.grade == g,
                        onSelected: (on) => setState(() {
                          e.grade = on ? g : null;
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
                if (e.error == 'اختر التقدير')
                  const Text('اختر التقدير',
                      style: TextStyle(color: DesignTokens.error)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _saved || _discarded,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (!leave || !mounted) return;
        setState(() => _discarded = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: DesignTokens.warmOffWhite,
          appBar: AppBar(
            title: Text(widget.studentName == null
                ? 'تسميع'
                : 'تسميع: ${widget.studentName}'),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(DesignTokens.space16),
            children: [
              for (final t in _visitWirds) _wirdCard(t),
              const SizedBox(height: DesignTokens.space8),
              TextField(
                controller: _feedback,
                maxLines: 2,
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                    labelText: 'ملاحظة تراها الطالبة/الطالب',
                    helperText: 'تظهر للطالب'),
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                controller: _private,
                maxLines: 2,
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                    labelText: 'ملاحظة خاصة بالمعلم',
                    helperText: 'لا يراها الطالب أبدًا'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('يحتاج متابعة'),
                value: _followUp,
                onChanged: (v) => setState(() {
                  _followUp = v;
                  _dirty = true;
                }),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.space8),
                  child: Text(_saveError!,
                      style: const TextStyle(color: DesignTokens.error)),
                ),
              const SizedBox(height: DesignTokens.space16),
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
                      : const Text('حفظ التسميع'),
                ),
              ),
              const SizedBox(height: DesignTokens.space24),
            ],
          ),
        ),
      ),
    );
  }
}
