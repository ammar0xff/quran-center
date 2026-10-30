import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/providers/sync_providers.dart';
import 'package:quran_center/core/sync/outbox.dart';
import 'package:quran_center/data/services/session_work.dart';
import 'package:quran_center/features/teacher/widgets/sync_status_bar.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';
import 'package:quran_center/features/director/attendance/attendance_administration_screen.dart'
    show attendanceStatusLabel;
import 'package:quran_center/features/teacher/home/teacher_home_data.dart'
    show sessionStatusLabel, teacherHomeProvider;
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

/// A teacher runs one session: start it, record attendance for each student,
/// then complete it. Attendance can be fixed only while the session is in
/// progress; afterwards corrections go through the director.
class TeacherSessionScreen extends ConsumerStatefulWidget {
  const TeacherSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<TeacherSessionScreen> createState() => _TeacherSessionScreenState();
}

class _TeacherSessionScreenState extends ConsumerState<TeacherSessionScreen> {
  SessionRoster? _roster;
  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  String get _centerId => ref.read(centerIdProvider);
  String get _teacherId => ref.read(actorProvider).id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(teacherSessionServiceProvider).loadRoster(
            centerId: _centerId,
            teacherId: _teacherId,
            sessionId: widget.sessionId,
          );
      if (!mounted) return;
      setState(() {
        _roster = r;
        _loading = false;
        _loadError = null;
      });
    } on SessionException catch (e) {
      if (!mounted) return;
      setState(() {
        _roster = null;
        _loading = false;
        _loadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'تعذر تحميل الجلسة. تحقق من اتصالك.';
      });
    }
  }

  void _toast(String message, {bool error = false}) {
    // Replace, never queue: a stale message must not delay a newer one.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? DesignTokens.error : DesignTokens.success,
      ));
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      ref.invalidate(teacherHomeProvider);
      if (mounted) _toast(successMessage);
    } on SessionException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (_) {
      if (mounted) _toast('تعذر تنفيذ الإجراء. حاول مرة أخرى.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(
        () => ref.read(teacherSessionServiceProvider).start(
            centerId: _centerId, teacherId: _teacherId, sessionId: widget.sessionId),
        'بدأت الجلسة',
      );

  Future<void> _complete() async {
    // Attendance still waiting to be sent would be refused once the session
    // is completed, so finishing waits until everything has reached the server.
    final work = ref.read(sessionWorkProvider);
    setState(() => _busy = true);
    try {
      await work.outbox.flush();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final waiting = work.unsyncedCount(widget.sessionId);
    if (waiting > 0) {
      if (mounted) {
        _toast(
            'لا يمكن إنهاء الجلسة قبل مزامنة $waiting تغييرات. تأكد من الاتصال أو راجع التغييرات المرفوضة.',
            error: true);
      }
      return;
    }
    await _load();
    if (!mounted) return;
    final missing = _roster?.missing.length ?? 0; // everything pending was sent above
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إنهاء الجلسة؟'),
          content: Text(missing == 0
              ? 'بعد الإنهاء لن تتمكن من تعديل الحضور؛ التعديل يتم عبر الإدارة.'
              : 'لم يُسجَّل حضور $missing طالبًا. بعد الإنهاء لن تتمكن من تسجيله أو تعديل الحضور؛ '
                  'التعديل يتم عبر الإدارة.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('رجوع')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('إنهاء الجلسة')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(teacherSessionServiceProvider).complete(
          centerId: _centerId, teacherId: _teacherId, sessionId: widget.sessionId),
      'تم إنهاء الجلسة',
    );
  }

  /// Saved on the device at once and sent in the background, so a dropped
  /// connection never loses it or makes the teacher wait.
  Future<void> _mark(String studentId, String name, AttendanceStatus status) async {
    try {
      await ref.read(sessionWorkProvider).markAttendance(
            centerId: _centerId,
            teacherId: _teacherId,
            sessionId: widget.sessionId,
            studentId: studentId,
            label: name,
            status: status,
          );
    } catch (_) {
      if (mounted) _toast('تعذر حفظ الحضور على الجهاز. حاول مرة أخرى.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(outboxSnapshotProvider); // rebuild as changes are sent or rejected
    ref.listen<AsyncValue<OutboxSnapshot>>(outboxSnapshotProvider, (prev, next) {
      final before = prev?.valueOrNull?.inScope(widget.sessionId).length ?? 0;
      final after = next.valueOrNull?.inScope(widget.sessionId).length ?? 0;
      if (after < before) _load(); // something was sent: refresh the server's view
    });
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('جلسة التسميع'),
          centerTitle: false,
          leading: BackButton(onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/teacher/home');
            }
          }),
        ),
        body: _body(),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final r = _roster;
    if (r == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError ?? 'الجلسة غير موجودة', textAlign: TextAlign.center),
              const SizedBox(height: DesignTokens.space12),
              OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    final s = r.session;
    final live = s.status == SessionStatus.inProgress;
    final scheduled = s.status == SessionStatus.scheduled;
    final work = ref.read(sessionWorkProvider);
    final pending = work.pendingAttendance(widget.sessionId);
    final pendingAssessments = <String, int>{};
    for (final o in work.outbox.snapshot.inScope(widget.sessionId)) {
      if (o.type == SessionWork.assessmentType) {
        final id = o.payload['studentId'] as String;
        pendingAssessments[id] = (pendingAssessments[id] ?? 0) + 1;
      }
    }
    final recorded = {...r.records.keys, ...pending.keys}.length;

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        Text(r.circleName ?? 'حلقة',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: DesignTokens.space4),
        Text('${s.startTime}–${s.endTime} • ${sessionStatusLabel(s.status)}',
            style: const TextStyle(color: DesignTokens.secondaryText)),
        SyncStatusBar(scope: widget.sessionId),
        const SizedBox(height: DesignTokens.space16),
        if (scheduled)
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('بدء الجلسة'),
          ),
        if (s.status == SessionStatus.completed)
          const Text('انتهت الجلسة. تعديل الحضور بعد انتهائها يتم عبر الإدارة.',
              style: TextStyle(color: DesignTokens.secondaryText, height: 1.5)),
        if (s.status == SessionStatus.cancelled)
          const Text('هذه الجلسة ملغاة.',
              style: TextStyle(color: DesignTokens.error)),
        const SizedBox(height: DesignTokens.space16),
        Text('الطلاب (${r.students.length})  •  سُجِّل $recorded',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: DesignTokens.space8),
        if (r.students.isEmpty)
          const Text('لا يوجد طلاب مسندون إليك في هذه الحلقة.',
              style: TextStyle(color: DesignTokens.secondaryText))
        else
          for (final st in r.students)
            _StudentRow(
              key: ValueKey(st.studentId),
              name: st.displayName,
              current: pending[st.studentId] != null
                  ? AttendanceStatusJson.fromJson(pending[st.studentId]!.payload['status'] as String?)
                  : r.records[st.studentId]?.status,
              editable: live,
              saving: false,
              syncNote: pending[st.studentId] == null
                  ? null
                  : (pending[st.studentId]!.failed
                      ? 'رُفض: ${pending[st.studentId]!.error}'
                      : 'بانتظار المزامنة'),
              syncFailed: pending[st.studentId]?.failed ?? false,
              assessments: (r.assessmentCounts[st.studentId] ?? 0) +
                  (pendingAssessments[st.studentId] ?? 0),
              onPick: (status) => _mark(st.studentId, st.displayName, status),
              onAssess: live
                  ? () async {
                      final saved = await context.push<bool>(
                          '/teacher/sessions/${widget.sessionId}/assess/${st.studentId}'
                          '?name=${Uri.encodeQueryComponent(st.displayName)}');
                      if (saved == true) await _load();
                    }
                  : null,
            ),
        if (live) ...[
          const SizedBox(height: DesignTokens.space24),
          FilledButton.icon(
            onPressed: _busy ? null : _complete,
            icon: const Icon(Icons.flag),
            label: const Text('إنهاء الجلسة'),
          ),
        ],
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    super.key,
    required this.name,
    required this.current,
    required this.editable,
    required this.saving,
    required this.syncNote,
    required this.syncFailed,
    required this.assessments,
    required this.onPick,
    required this.onAssess,
  });

  final String name;
  final AttendanceStatus? current;
  final bool editable;
  final bool saving;
  final String? syncNote;
  final bool syncFailed;
  final int assessments;
  final ValueChanged<AttendanceStatus> onPick;
  final VoidCallback? onAssess;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (saving)
                  const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else if (syncNote != null)
                  Text(syncNote!,
                      style: TextStyle(
                          color: syncFailed ? DesignTokens.error : DesignTokens.warning,
                          fontSize: 12))
                else if (current == null)
                  const Text('لم يُسجَّل',
                      style: TextStyle(color: DesignTokens.warning, fontSize: 12)),
              ],
            ),
            const SizedBox(height: DesignTokens.space8),
            Wrap(
              spacing: DesignTokens.space8,
              children: [
                for (final st in AttendanceStatus.values)
                  ChoiceChip(
                    label: Text(attendanceStatusLabel(st)),
                    selected: current == st,
                    onSelected: (editable && !saving) ? (_) => onPick(st) : null,
                  ),
              ],
            ),
            if (onAssess != null || assessments > 0)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space4),
                child: Row(
                  children: [
                    if (onAssess != null)
                      TextButton.icon(
                        onPressed: onAssess,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('تسميع'),
                      ),
                    if (assessments > 0)
                      Text('تسميعات اليوم: $assessments',
                          style: const TextStyle(
                              fontSize: 12, color: DesignTokens.secondaryText)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
