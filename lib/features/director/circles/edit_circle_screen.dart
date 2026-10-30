import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/circle_validation.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/circle_service.dart';
import 'package:quran_center/features/director/circles/weekly_schedule_editor.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Edits a circle. Changing the teacher also moves the circle's students and
/// upcoming sessions to that teacher in one atomic step (see [CircleService]).
class EditCircleScreen extends ConsumerStatefulWidget {
  const EditCircleScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<EditCircleScreen> createState() => _EditCircleScreenState();
}

class _EditCircleScreenState extends ConsumerState<EditCircleScreen> {
  final _name = TextEditingController();
  final _level = TextEditingController();
  final _capacity = TextEditingController();
  final _duration = TextEditingController();
  final _description = TextEditingController();
  String _mode = 'onsite';
  String? _teacherId;
  String? _originalTeacherId;
  List<Teacher> _teachers = [];
  Map<int, (String, String)> _schedule = {};
  String? _scheduleError;

  CircleFormErrors _errors = const CircleFormErrors();
  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _level, _capacity, _duration, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final centerId = ref.read(centerIdProvider);
      final circle =
          await ref.read(circleRepositoryProvider).getCircle(widget.circleId);
      if (!mounted) return;
      if (circle == null ||
          circle.centerId != centerId ||
          circle.status != CircleStatus.active) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      final teachers = (await ref
              .read(teacherRepositoryProvider)
              .getTeachersByCenter(centerId))
          .where((t) => t.status == AccountStatus.active)
          .toList();
      if (!mounted) return;
      _name.text = circle.name;
      _level.text = circle.educationalLevel;
      _capacity.text = '${circle.maxCapacity}';
      _duration.text = '${circle.sessionDurationMinutes}';
      _description.text = circle.description ?? '';
      setState(() {
        _mode =
            const {'onsite', 'online', 'hybrid'}.contains(circle.locationOrMode)
                ? circle.locationOrMode
                : 'onsite';
        _teachers = teachers;
        _schedule = scheduleToMap(circle.weeklySchedule);
        // A suspended current teacher is not selectable; keep the value out of
        // the dropdown so it does not assert, but remember it for messaging.
        _originalTeacherId = circle.assignedTeacherId;
        _teacherId =
            teachers.any((t) => t.teacherId == circle.assignedTeacherId)
                ? circle.assignedTeacherId
                : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _missing = true;
        _error = 'تعذر تحميل الحلقة';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final errors = validateCircleForm(
      name: _name.text,
      capacity: _capacity.text,
      duration: _duration.text,
      scheduleDays: const {},
      start: '',
      end: '',
    );
    final scheduleError = weeklyScheduleError(_schedule);
    setState(() {
      _errors = errors;
      _scheduleError = scheduleError;
      _error = null;
    });
    if (errors.hasErrors || scheduleError != null) return;

    setState(() => _saving = true);
    try {
      final actor = ref.read(actorProvider);
      final changed = await ref.read(circleServiceProvider).update(
            widget.circleId,
            centerId: ref.read(centerIdProvider),
            actorId: actor.id,
            actorRole: actor.role,
            name: _name.text,
            educationalLevel: _level.text,
            description: _description.text,
            maxCapacity: int.parse(_capacity.text.trim()),
            sessionDurationMinutes: int.parse(_duration.text.trim()),
            locationOrMode: _mode,
            teacherId: _teacherId,
            weeklySchedule: scheduleFromMap(_schedule),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(changed ? 'تم حفظ التعديلات' : 'لا توجد تعديلات لحفظها'),
        backgroundColor:
            changed ? DesignTokens.success : DesignTokens.secondaryText,
      ));
      context.pop();
    } on CircleException catch (e) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = e.message;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ التعديلات. حاول مرة أخرى.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherWillChange = _teacherId != _originalTeacherId;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('تعديل الحلقة'), centerTitle: false),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _missing
                ? EmptyState(_error ?? 'الحلقة غير موجودة أو مؤرشفة')
                : ListView(
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
                        decoration: const InputDecoration(
                            labelText: 'المستوى التعليمي'),
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      TextField(
                        controller: _description,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'وصف (اختياري)'),
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _capacity,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: 'السعة القصوى *',
                                  errorText: _errors.capacity),
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
                        decoration:
                            const InputDecoration(labelText: 'المكان / النمط'),
                        items: const [
                          DropdownMenuItem(
                              value: 'onsite', child: Text('حضوري')),
                          DropdownMenuItem(
                              value: 'online', child: Text('عن بعد')),
                          DropdownMenuItem(
                              value: 'hybrid', child: Text('مختلط')),
                        ],
                        onChanged: (v) => setState(() => _mode = v ?? 'onsite'),
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      DropdownButtonFormField<String?>(
                        value: _teacherId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'المعلم'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('بدون معلم')),
                          for (final t in _teachers)
                            DropdownMenuItem<String?>(
                                value: t.teacherId, child: Text(t.fullName)),
                        ],
                        onChanged: (v) => setState(() => _teacherId = v),
                      ),
                      const SizedBox(height: DesignTokens.space20),
                      const Text('الجدول الأسبوعي',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: DesignTokens.space8),
                      WeeklyScheduleEditor(
                        value: _schedule,
                        error: _scheduleError,
                        onChanged: (v) => setState(() => _schedule = v),
                      ),
                      if (teacherWillChange)
                        const Padding(
                          padding: EdgeInsets.only(top: DesignTokens.space8),
                          child: Text(
                            'عند تغيير المعلم يُنقل طلاب الحلقة وجلساتها القادمة إلى المعلم الجديد. '
                            'تبقى الجلسات المنتهية باسم من أجراها.',
                            style: TextStyle(
                                color: DesignTokens.warning, height: 1.5),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: DesignTokens.space16),
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: DesignTokens.error)),
                        ),
                      const SizedBox(height: DesignTokens.space24),
                      SizedBox(
                        height: DesignTokens.buttonHeight,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 3),
      ),
    );
  }
}
