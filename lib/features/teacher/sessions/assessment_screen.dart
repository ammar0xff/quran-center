import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/assessment_validation.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/sync_providers.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';

String assessmentTypeLabel(AssessmentType t) {
  switch (t) {
    case AssessmentType.newMemorization:
      return 'حفظ جديد';
    case AssessmentType.recentRevision:
      return 'مراجعة قريبة';
    case AssessmentType.longTermRevision:
      return 'مراجعة بعيدة';
    case AssessmentType.generalRecitation:
      return 'تلاوة عامة';
  }
}

/// Records a memorization / revision assessment for one student in the
/// teacher's in-progress session. The private note is clearly separated from
/// the feedback the student will see.
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
  AssessmentType _type = AssessmentType.newMemorization;
  int? _surah;
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _mistakes = TextEditingController(text: '0');
  final _category = TextEditingController();
  final _reference = TextEditingController();
  final _correction = TextEditingController();
  final _strengths = TextEditingController();
  final _improve = TextEditingController();
  final _feedback = TextEditingController();
  final _private = TextEditingController();
  final _next = TextEditingController();
  final Map<String, int> _scores = {};
  bool _followUp = false;
  DateTime? _nextReview;

  AssessmentErrors _errors = const AssessmentErrors();
  bool _saving = false;
  bool _saved = false;
  bool _discarded = false;
  String? _saveError;
  bool _dirty = false;

  // Fixed for the life of this form, so a retried save never duplicates.
  final String _recordId = 'm_${DateTime.now().microsecondsSinceEpoch}';
  final DateTime _assessedAt = DateTime.now();

  List<TextEditingController> get _all => [
        _start, _end, _mistakes, _category, _reference, _correction,
        _strengths, _improve, _feedback, _private, _next,
      ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final errors = validateAssessment(
      surah: _surah,
      startAyah: _start.text,
      endAyah: _end.text,
      mistakes: _mistakes.text,
      scores: _scores,
    );
    setState(() {
      _errors = errors;
      _saveError = null;
    });
    if (errors.hasErrors) return;

    setState(() => _saving = true);
    try {
      // Saved on the device first and sent in the background: nothing the
      // teacher typed is lost if the connection drops.
      await ref.read(sessionWorkProvider).saveAssessment(
            label: widget.studentName,
            centerId: ref.read(centerIdProvider),
            teacherId: ref.read(actorProvider).id,
            sessionId: widget.sessionId,
            studentId: widget.studentId,
            recordId: _recordId,
            assessedAt: _assessedAt,
            draft: AssessmentDraft(
              type: _type,
              surah: _surah!,
              startAyah: int.parse(_start.text.trim()),
              endAyah: int.parse(_end.text.trim()),
              scores: _scores,
              mistakesCount: int.parse(_mistakes.text.trim()),
              mistakeCategory: _category.text,
              mistakeReference: _reference.text,
              teacherCorrection: _correction.text,
              requiresFollowUp: _followUp,
              strengths: _strengths.text,
              areasForImprovement: _improve.text,
              studentVisibleFeedback: _feedback.text,
              privateNote: _private.text,
              recommendedNextAssignment: _next.text,
              suggestedNextReviewDate: _nextReview,
            ),
          );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('تم حفظ التسميع'), backgroundColor: DesignTokens.success));
      context.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'تعذر الحفظ على الجهاز. بياناتك ما زالت في النموذج، حاول مرة أخرى.';
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty && _scores.isEmpty && _surah == null) return true;
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

  Widget _field(String label, TextEditingController c,
          {int lines = 1, TextInputType? type, String? error, String? helper}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: DesignTokens.space12),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, errorText: error, helperText: helper),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final surah = _surah == null ? null : surahByNumber(_surah!);
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
            padding: const EdgeInsets.all(DesignTokens.space20),
            children: [
              DropdownButtonFormField<AssessmentType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع التسميع'),
                items: [
                  for (final t in AssessmentType.values)
                    DropdownMenuItem(value: t, child: Text(assessmentTypeLabel(t))),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: DesignTokens.space16),
              DropdownButtonFormField<int>(
                value: _surah,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'السورة *', errorText: _errors.surah),
                items: [
                  for (final s in surahs)
                    DropdownMenuItem(value: s.number, child: Text('${s.number}. ${s.name}')),
                ],
                onChanged: (v) => setState(() {
                  _surah = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _start,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'من آية *', errorText: _errors.range),
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
                      style: const TextStyle(
                          fontSize: 12, color: DesignTokens.secondaryText)),
                ),
              const SizedBox(height: DesignTokens.space20),
              const Text('المعايير (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              if (_errors.scores != null)
                Text(_errors.scores!, style: const TextStyle(color: DesignTokens.error)),
              for (final c in assessmentCriteria)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.space8),
                  child: Row(
                    children: [
                      SizedBox(width: 100, child: Text(c.label)),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (var n = criterionMinScore; n <= criterionMaxScore; n++)
                              ChoiceChip(
                                label: Text('$n'),
                                selected: _scores[c.id] == n,
                                onSelected: (on) => setState(() {
                                  _dirty = true;
                                  on ? _scores[c.id] = n : _scores.remove(c.id);
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: DesignTokens.space20),
              _field('عدد الأخطاء *', _mistakes,
                  type: TextInputType.number, error: _errors.mistakes),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('تفاصيل الأخطاء (اختياري)'),
                children: [
                  _field('نوع الخطأ', _category),
                  _field('الموضع', _reference),
                  _field('التصحيح / الملاحظة', _correction, lines: 2),
                ],
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
              const SizedBox(height: DesignTokens.space8),
              _field('نقاط القوة', _strengths, lines: 2),
              _field('ما يحتاج تحسينًا', _improve, lines: 2),
              _field('ملاحظة تراها الطالبة/الطالب', _feedback,
                  lines: 2, helper: 'تظهر للطالب'),
              _field('ملاحظة خاصة بالمعلم', _private,
                  lines: 2, helper: 'لا يراها الطالب أبدًا'),
              _field('الواجب المقترح التالي', _next),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _nextReview ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) {
                    setState(() {
                      _nextReview = d;
                      _dirty = true;
                    });
                  }
                },
                icon: const Icon(Icons.event),
                label: Text(_nextReview == null
                    ? 'موعد المراجعة القادمة (اختياري)'
                    : 'المراجعة القادمة: ${DateFormat.yMMMd('ar').format(_nextReview!)}'),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.space16),
                  child: Text(_saveError!, style: const TextStyle(color: DesignTokens.error)),
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
                      : const Text('حفظ التسميع'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
