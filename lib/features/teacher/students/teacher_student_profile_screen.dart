import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/features/shared/level_summary.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/task_service.dart';
import 'package:quran_center/features/director/attendance/attendance_administration_screen.dart'
    show attendanceStatusLabel;
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart'
    show assessmentTypeLabel;
import 'package:quran_center/features/teacher/students/teacher_student_data.dart';
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

String _date(DateTime d) => DateFormat.yMMMd('ar').format(d);

String ayahRangeText(int surah, int start, int end) {
  final name = surahByNumber(surah)?.name ?? 'سورة $surah';
  return start == end ? '$name: $start' : '$name: $start–$end';
}

/// What a teacher sees of one of their students: the assessments they
/// recorded, the tasks they assigned (with verification), and attendance.
class TeacherStudentProfileScreen extends ConsumerWidget {
  const TeacherStudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherStudentProfileProvider(studentId));
    final data = async.valueOrNull;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('ملف الطالب'), centerTitle: false),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل ملف الطالب'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref
                        .invalidate(teacherStudentProfileProvider(studentId)),
                    child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
          data: (d) {
            if (d == null)
              return const Center(child: Text('الطالب غير موجود ضمن طلابك'));
            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(DesignTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.student.displayName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: DesignTokens.space4),
                        Text(
                          [
                            if (d.circle != null) d.circle!.name,
                            'المستوى: ${d.student.educationalLevel}',
                          ].join(' • '),
                          style: const TextStyle(
                              color: DesignTokens.secondaryText),
                        ),
                        const SizedBox(height: DesignTokens.space8),
                        LevelSummary(level: computeLevel(d.assessments)),
                      ],
                    ),
                  ),
                  const TabBar(tabs: [
                    Tab(text: 'التسميع'),
                    Tab(text: 'المهام'),
                    Tab(text: 'الحضور'),
                  ]),
                  Expanded(
                    child: TabBarView(children: [
                      _AssessmentsTab(data: d),
                      _TasksTab(data: d, studentId: studentId),
                      _AttendanceTab(data: d),
                    ]),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: data == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  final added = await context
                      .push<bool>('/teacher/students/$studentId/tasks/new');
                  if (added == true) {
                    ref.invalidate(teacherStudentProfileProvider(studentId));
                    ref.invalidate(teacherStudentsProvider);
                  }
                },
                icon: const Icon(Icons.add_task),
                label: const Text('مهمة جديدة'),
              ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 1),
      ),
    );
  }
}

Widget _empty(String m) => Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Text(m, textAlign: TextAlign.center),
      ),
    );

class _AssessmentsTab extends StatelessWidget {
  const _AssessmentsTab({required this.data});
  final TeacherStudentProfile data;

  @override
  Widget build(BuildContext context) {
    if (data.assessments.isEmpty)
      return _empty('لم تُسجَّل تسميعات لهذا الطالب بعد.');
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        for (final a in data.assessments)
          _AssessmentCard(
              a, data.privateNotes[a.recordId], a.teacherId == data.teacherId)
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard(this.a, this.privateNote, this.mine);
  final MemorizationRecord a;
  final String? privateNote;

  /// False when a visiting teacher (not this student's usual one) heard it.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    '${assessmentTypeLabel(a.assessmentType)} • ${ayahRangeText(a.surah, a.startAyah, a.endAyah)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (a.grade != null) GradeChip(a.grade!),
            ]),
            const SizedBox(height: DesignTokens.space4),
            Text(
                '${_date(a.assessedAt)}${mine ? '' : ' • سمعتها معلمة أخرى'}'
                '${a.requiresFollowUp ? ' • يحتاج متابعة' : ''}',
                style: const TextStyle(color: DesignTokens.secondaryText)),
            if (a.studentVisibleFeedback != null)
              Text('للطالب: ${a.studentVisibleFeedback}'),
            if (privateNote != null)
              Container(
                margin: const EdgeInsets.only(top: DesignTokens.space8),
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Text('ملاحظة خاصة (لا يراها الطالب): $privateNote'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.data, required this.studentId});
  final TeacherStudentProfile data;
  final String studentId;

  Future<void> _verify(
      BuildContext context, WidgetRef ref, LearningTask t) async {
    var result = verificationPassed;
    final feedback = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('التحقق من المهمة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: verificationPassed,
                  groupValue: result,
                  title: const Text('أتقنها — اعتماد الإنجاز'),
                  onChanged: (v) => setState(() => result = v!),
                ),
                RadioListTile<String>(
                  value: verificationNeedsImprovement,
                  groupValue: result,
                  title: const Text('تحتاج إعادة'),
                  onChanged: (v) => setState(() => result = v!),
                ),
                TextField(
                  controller: feedback,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, 'تم حفظ التحقق', () {
      return ref.read(taskServiceProvider).verify(
            centerId: ref.read(centerIdProvider),
            teacherId: ref.read(actorProvider).id,
            taskId: t.taskId,
            result: result,
            feedback: feedback.text,
          );
    });
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, LearningTask t) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء المهمة'),
          content: TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'سبب الإلغاء *'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('رجوع')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('إلغاء المهمة')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, 'تم إلغاء المهمة', () {
      return ref.read(taskServiceProvider).cancel(
            centerId: ref.read(centerIdProvider),
            teacherId: ref.read(actorProvider).id,
            taskId: t.taskId,
            reason: reason.text,
          );
    });
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String success,
      Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(teacherStudentProfileProvider(studentId));
      ref.invalidate(teacherStudentsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(success), backgroundColor: DesignTokens.success));
    } on TaskException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: DesignTokens.error));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('تعذر تنفيذ الإجراء. حاول مرة أخرى.'),
            backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.tasks.isEmpty) return _empty('لم تُسند مهام لهذا الطالب بعد.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DesignTokens.space16, DesignTokens.space16, DesignTokens.space16, 96),
      children: [
        for (final t in data.tasks)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${taskTypeLabel(t.taskType)} • ${ayahRangeText(t.surah, t.startAyah, t.endAyah)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    '${taskStatusLabel(t.status)}'
                    '${t.isOverdue ? ' • متأخرة' : ''} • الموعد ${_date(t.dueDate)}',
                    style: TextStyle(
                        color: t.isOverdue
                            ? DesignTokens.error
                            : DesignTokens.secondaryText,
                        fontWeight: FontWeight.w600),
                  ),
                  if (t.teacherInstructions.isNotEmpty)
                    Text(t.teacherInstructions),
                  if (t.selfReportedPractice != null)
                    Text(
                      'بلاغ الطالب بالتدريب (غير مُتحقَّق منه) — ${_date(t.selfReportedPractice!.reportedAt)}',
                      style: const TextStyle(color: DesignTokens.warning),
                    ),
                  if (t.teacherVerification != null)
                    Text(
                        'تحقق المعلم: ${t.teacherVerification!.result == verificationPassed ? 'أتقنها' : 'تحتاج إعادة'}'
                        '${t.teacherVerification!.feedback == null ? '' : ' — ${t.teacherVerification!.feedback}'}'),
                  if (t.status != TaskStatus.completed &&
                      t.status != TaskStatus.cancelled)
                    Row(
                      children: [
                        TextButton(
                            onPressed: () => _verify(context, ref, t),
                            child: const Text('تحقق')),
                        TextButton(
                            onPressed: () => _cancel(context, ref, t),
                            child: const Text('إلغاء المهمة')),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.data});
  final TeacherStudentProfile data;

  @override
  Widget build(BuildContext context) {
    if (data.attendance.isEmpty)
      return _empty('لا توجد سجلات حضور سجّلتَها لهذا الطالب بعد.');
    final a = data.attendanceSummary;
    final rate = a.rate;
    final list = [...data.attendance]..sort((x, y) {
        final dx = data.sessionDates[x.sessionId] ?? x.createdAt;
        final dy = data.sessionDates[y.sessionId] ?? y.createdAt;
        return dy.compareTo(dx);
      });
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate == null
                      ? 'نسبة الحضور: —'
                      : 'نسبة الحضور: ${(rate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                    'حاضر ${a.present} • متأخر ${a.late} • غائب ${a.absent} • معذور ${a.excused}',
                    style: const TextStyle(color: DesignTokens.secondaryText)),
              ],
            ),
          ),
        ),
        for (final r in list)
          ListTile(
            title: Text(attendanceStatusLabel(r.status)),
            subtitle:
                Text(_date(data.sessionDates[r.sessionId] ?? r.createdAt)),
          ),
      ],
    );
  }
}
