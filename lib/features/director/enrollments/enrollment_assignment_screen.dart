import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/enrollment_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Assigns a student to a circle.
///
/// Only active students and active circles of the signed-in director's center
/// are offered. A student has one active enrolment at a time, so assigning to
/// a new circle transfers them (the old enrolment is kept as history). All the
/// rules are enforced by [EnrollmentService]; this screen shows its answer.
class EnrollmentAssignmentScreen extends ConsumerStatefulWidget {
  const EnrollmentAssignmentScreen({super.key, this.initialStudentId, this.initialCircleId});

  /// Preselected student, when opened from a student's menu.
  final String? initialStudentId;

  /// Preselected circle, when opened from a circle's page.
  final String? initialCircleId;

  @override
  ConsumerState<EnrollmentAssignmentScreen> createState() =>
      _EnrollmentAssignmentScreenState();
}

class _EnrollmentAssignmentScreenState
    extends ConsumerState<EnrollmentAssignmentScreen> {
  final _reason = TextEditingController();
  String? _studentId;
  String? _circleId;
  DateTime _startDate = DateTime.now();

  List<Student> _students = [];
  List<Circle> _circles = [];
  Map<String, String> _teacherNames = {};
  Map<String, int> _counts = {};
  Map<String, String> _currentCircle = {}; // studentId -> circle name

  bool _loading = true;
  bool _submitting = false;
  bool _done = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final centerId = ref.read(centerIdProvider);
      final students = (await ref
              .read(studentRepositoryProvider)
              .getStudentsByCenter(centerId))
          .where((s) => s.enrollmentStatus == EnrollmentStatus.active)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      final allCircles =
          await ref.read(circleRepositoryProvider).getCirclesByCenter(centerId);
      final circles = allCircles
          .where((c) => c.status == CircleStatus.active)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final teachers =
          await ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId);
      final enrollments = ref.read(enrollmentRepositoryProvider);

      final counts = <String, int>{};
      final byCircleId = {for (final c in allCircles) c.circleId: c.name};
      final current = <String, String>{};
      for (final c in circles) {
        final active = await enrollments.getActiveEnrollmentsForCircle(c.circleId, centerId: centerId);
        counts[c.circleId] = active.length;
        for (final e in active) {
          current[e.studentId] = byCircleId[e.circleId] ?? '';
        }
      }
      if (!mounted) return;
      final preselect = widget.initialStudentId;
      setState(() {
        _students = students;
        _circles = circles;
        _teacherNames = {for (final t in teachers) t.teacherId: t.fullName};
        _counts = counts;
        _currentCircle = current;
        if (preselect != null && students.any((s) => s.studentId == preselect)) {
          _studentId = preselect;
        }
        final circlePre = widget.initialCircleId;
        if (circlePre != null && circles.any((c) => c.circleId == circlePre)) {
          _circleId = circlePre;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'تعذر تحميل الطلاب والحلقات';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting || _done) return;
    if (_studentId == null || _circleId == null) {
      setState(() => _error = 'اختر الطالب والحلقة أولًا.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final actor = ref.read(actorProvider);
      await ref.read(enrollmentServiceProvider).assign(
            centerId: ref.read(centerIdProvider),
            studentId: _studentId!,
            circleId: _circleId!,
            actorId: actor.id,
            actorRole: actor.role,
            startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
            reason: _reason.text,
          );
      if (!mounted) return;
      setState(() => _done = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تعيين الطالب للحلقة'),
        backgroundColor: DesignTokens.success,
      ));
      context.go('/director/students');
    } on EnrollmentAssignmentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر حفظ التعيين. حاول مرة أخرى.');
      }
    } finally {
      if (mounted && !_done) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('تعيين الطالب للحلقة'), centerTitle: false),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        const SizedBox(height: DesignTokens.space12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : (_students.isEmpty || _circles.isEmpty)
                    ? _prerequisites()
                    : _form(),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }

  Widget _prerequisites() => Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_late_outlined,
                  size: 56, color: DesignTokens.secondaryText),
              const SizedBox(height: DesignTokens.space16),
              Text(
                _students.isEmpty
                    ? 'لا يوجد طلاب منتظمون لتعيينهم.'
                    : 'لا توجد حلقات نشطة. أنشئ حلقة أولًا.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space16),
              FilledButton(
                onPressed: () => context.push(_students.isEmpty
                    ? '/director/students/add'
                    : '/director/circles/add'),
                child: Text(_students.isEmpty ? 'إضافة طالب' : 'إنشاء حلقة'),
              ),
            ],
          ),
        ),
      );

  Widget _form() {
    final current = _studentId == null ? null : _currentCircle[_studentId];
    final selectedCircle = _circleId == null
        ? null
        : _circles.firstWhere((c) => c.circleId == _circleId);
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        DropdownButtonFormField<String>(
          value: _studentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الطالب *'),
          items: [
            for (final s in _students)
              DropdownMenuItem(value: s.studentId, child: Text(s.displayName)),
          ],
          onChanged: (v) => setState(() {
            _studentId = v;
            _error = null;
          }),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space8),
            child: Text(
              'الطالب مسجّل حاليًا في «$current». سيُنقل إلى الحلقة الجديدة ويبقى تسجيله السابق في السجل.',
              style: const TextStyle(color: DesignTokens.warning, height: 1.5),
            ),
          ),
        const SizedBox(height: DesignTokens.space16),
        DropdownButtonFormField<String>(
          value: _circleId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الحلقة *'),
          items: [
            for (final c in _circles)
              DropdownMenuItem(
                value: c.circleId,
                child: Text('${c.name}  (${_counts[c.circleId] ?? 0}/${c.maxCapacity})'),
              ),
          ],
          onChanged: (v) => setState(() {
            _circleId = v;
            _error = null;
          }),
        ),
        if (selectedCircle != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space8),
            child: Text(
              selectedCircle.assignedTeacherId == null
                  ? 'هذه الحلقة بلا معلم بعد.'
                  : 'معلم الحلقة: ${_teacherNames[selectedCircle.assignedTeacherId] ?? '—'}',
              style: const TextStyle(color: DesignTokens.secondaryText),
            ),
          ),
        const SizedBox(height: DesignTokens.space16),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event),
          label: Text('تاريخ البداية: ${DateFormat.yMMMd('ar').format(_startDate)}'),
        ),
        const SizedBox(height: DesignTokens.space16),
        TextField(
          controller: _reason,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'سبب / ملاحظة (اختياري)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: DesignTokens.space16),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: DesignTokens.error)),
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space24),
        SizedBox(
          height: DesignTokens.buttonHeight,
          child: FilledButton(
            onPressed: (_submitting || _done) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('تعيين'),
          ),
        ),
      ],
    );
  }
}
