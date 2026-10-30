import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/features/shared/level_summary.dart';
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart'
    show assessmentTypeLabel;
import 'package:quran_center/data/models/audit_log.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/features/director/attendance/attendance_administration_screen.dart'
    show attendanceStatusLabel;
import 'package:quran_center/features/director/students/account_access_tab.dart';
import 'package:quran_center/features/director/students/student_management_list_screen.dart'
    show accessLabel, enrollmentStatusColor, enrollmentStatusLabel;
import 'package:quran_center/features/director/students/student_profile_data.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

String _date(DateTime d) => DateFormat.yMMMd('ar').format(d);

/// Director's view of one student: overview, enrolment history, attendance,
/// login access and the audit trail. Everything shown is read from the
/// student's own records; sections that depend on sessions not yet recorded
/// say so instead of showing placeholder numbers.
class DirectorStudentProfileScreen extends ConsumerWidget {
  const DirectorStudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentProfileProvider(studentId));
    final data = async.valueOrNull;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('ملف الطالب'),
          centerTitle: false,
          actions: [
            if (data != null)
              IconButton(
                tooltip: 'تعديل البيانات',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await context.push('/director/students/$studentId/edit');
                  ref.invalidate(studentProfileProvider(studentId));
                },
              ),
          ],
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل ملف الطالب'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(studentProfileProvider(studentId)),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (d) {
            if (d == null) return const Center(child: Text('الطالب غير موجود'));
            return DefaultTabController(
              length: 6,
              child: Column(
                children: [
                  _Header(student: d.student),
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'نظرة عامة'),
                      Tab(text: 'المستوى'),
                      Tab(text: 'التسجيل'),
                      Tab(text: 'الحضور'),
                      Tab(text: 'الدخول'),
                      Tab(text: 'سجل التدقيق'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(data: d),
                        _LevelTab(data: d),
                        _EnrollmentTab(data: d),
                        _AttendanceTab(data: d),
                        AccountAccessTab(
                          student: d.student,
                          onChanged: () =>
                              ref.invalidate(studentProfileProvider(studentId)),
                        ),
                        _AuditTab(logs: d.audit, userNames: d.userNames),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final color = enrollmentStatusColor(student.enrollmentStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DesignTokens.borders)),
      ),
      child: Row(
        children: [
          Rosette(
              size: 60,
              color: DesignTokens.primaryDarkGreen,
              child: Text(
                  student.fullName.isNotEmpty ? student.fullName[0] : 'ط',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24))),
          const SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.displayName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.mainText)),
                const SizedBox(height: DesignTokens.space4),
                Text('المستوى: ${student.educationalLevel}',
                    style: const TextStyle(
                        fontSize: 14, color: DesignTokens.secondaryText)),
                const SizedBox(height: DesignTokens.space4),
                Wrap(
                  spacing: DesignTokens.space12,
                  children: [
                    Text(enrollmentStatusLabel(student.enrollmentStatus),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    Text(accessLabel(student.accountMode),
                        style: const TextStyle(
                            fontSize: 13, color: DesignTokens.secondaryText)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(
          vertical: DesignTokens.space12, horizontal: DesignTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: DesignTokens.secondaryText)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: DesignTokens.mainText,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

Widget _empty(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline,
                size: 44, color: DesignTokens.secondaryText),
            const SizedBox(height: DesignTokens.space12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.data});
  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    final s = data.student;
    final current = data.currentEnrollment;
    final circle =
        current == null ? null : (data.circleNames[current.circleId] ?? '—');
    final teacher = current?.teacherId == null
        ? null
        : (data.teacherNames[current!.teacherId] ?? '—');
    final att = data.attendanceSummary;
    final rate = att.rate;

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        Card(
          child: Column(children: [
            _row('الحلقة الحالية', circle ?? 'غير مسجّل في حلقة'),
            const Divider(height: 1),
            _row('المعلم', teacher ?? 'لا يوجد معلم'),
            const Divider(height: 1),
            _row('الاسم الكامل', s.fullName),
            if (s.preferredName != null) ...[
              const Divider(height: 1),
              _row('الاسم المفضل', s.preferredName!),
            ],
            const Divider(height: 1),
            _row('تاريخ التسجيل', _date(s.createdAt)),
            const Divider(height: 1),
            _row(
              'الحضور',
              att.recorded == 0
                  ? 'لا توجد سجلات حضور بعد'
                  : (rate == null
                      ? '—'
                      : '${(rate * 100).toStringAsFixed(1)}% (${att.recorded} سجل)'),
            ),
          ]),
        ),
        if (data.adminNote != null) ...[
          const SizedBox(height: DesignTokens.space16),
          Card(
            child: Column(children: [
              _row('ملاحظات إدارية', data.adminNote!),
            ]),
          ),
        ],
        const SizedBox(height: DesignTokens.space16),
        if (s.enrollmentStatus == EnrollmentStatus.active)
          OutlinedButton.icon(
            onPressed: () => context
                .push('/director/enrollments/assign?student=${s.studentId}'),
            icon: const Icon(Icons.assignment_ind),
            label: Text(current == null ? 'تعيين لحلقة' : 'نقل إلى حلقة أخرى'),
          ),
        const SizedBox(height: DesignTokens.space16),
        const Text(
          'السجل التعليمي والخطط تظهر هنا عند تسجيل الجلسات والتقييمات.',
          style: TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
        ),
      ],
    );
  }
}

String _enrollmentStatusText(EnrollmentStatus s) {
  switch (s) {
    case EnrollmentStatus.active:
      return 'حالي';
    case EnrollmentStatus.transferred:
      return 'منقول';
    case EnrollmentStatus.completed:
      return 'مكتمل';
    case EnrollmentStatus.withdrawn:
      return 'منسحب';
    case EnrollmentStatus.archived:
      return 'مؤرشف';
  }
}

class _LevelTab extends StatelessWidget {
  const _LevelTab({required this.data});
  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    final level = computeLevel(data.wirds);
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: LevelSummary(level: level),
          ),
        ),
        if (data.wirds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(DesignTokens.space24),
            child: Text('لم يُسجَّل لهذا الطالب تسميع بعد.',
                textAlign: TextAlign.center),
          ),
        for (final w in data.wirds)
          ListTile(
            title: Text(
                '${assessmentTypeLabel(w.assessmentType)} • ${surahByNumber(w.surah)?.name ?? w.surah}: ${w.startAyah}–${w.endAyah}'),
            subtitle: Text(
                '${_date(w.assessedAt)} • ${data.teacherNames[w.teacherId] ?? 'معلمة'}'),
            trailing: w.grade == null ? null : GradeChip(w.grade!),
          ),
      ],
    );
  }
}

class _EnrollmentTab extends StatelessWidget {
  const _EnrollmentTab({required this.data});
  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    if (data.enrollments.isEmpty)
      return _empty('لم يُسجَّل الطالب في أي حلقة بعد.');
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        for (final Enrollment e in data.enrollments)
          Card(
            child: ListTile(
              title: Text(data.circleNames[e.circleId] ?? 'حلقة غير معروفة'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space4),
                child: Text([
                  _enrollmentStatusText(e.status),
                  'من ${_date(e.startDate)}',
                  if (e.endDate != null) 'إلى ${_date(e.endDate!)}',
                  if (e.teacherId != null)
                    'المعلم: ${data.teacherNames[e.teacherId] ?? '—'}',
                  if (e.changeReason != null) 'السبب: ${e.changeReason}',
                ].join(' • ')),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.data});
  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    if (data.attendance.isEmpty) return _empty('لا توجد سجلات حضور بعد.');
    final a = data.attendanceSummary;
    final rate = a.rate;
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
                const SizedBox(height: DesignTokens.space4),
                Text(
                    'حاضر ${a.present} • متأخر ${a.late} • غائب ${a.absent} • معذور ${a.excused}',
                    style: const TextStyle(color: DesignTokens.secondaryText)),
              ],
            ),
          ),
        ),
        for (final r in data.attendance)
          ListTile(
            title: Text(attendanceStatusLabel(r.status)),
            subtitle: Text([
              _date(data.sessionDates[r.sessionId] ?? r.createdAt),
              if (r.note != null) r.note!,
              if (r.correctionMetadata != null) 'مصحّح',
            ].join(' • ')),
          ),
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.logs, required this.userNames});
  final List<AuditLog> logs;
  final Map<String, String> userNames;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return _empty('لا توجد سجلات تدقيق لهذا الطالب بعد.');
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        for (final l in logs)
          Card(
            child: ListTile(
              title: Text(auditActionLabel(l.action)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space4),
                child: Text([
                  DateFormat.yMMMd('ar').add_jm().format(l.createdAt),
                  if (l.actorUserId != null)
                    'بواسطة: ${userNames[l.actorUserId] ?? l.actorUserId}',
                  if (l.reason != null) 'السبب: ${l.reason}',
                ].join(' • ')),
              ),
            ),
          ),
      ],
    );
  }
}
