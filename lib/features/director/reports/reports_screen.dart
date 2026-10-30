import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/csv.dart';
import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

final reportDataProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final ds = ref.read(firestoreDataSourceProvider);
  final (
    students,
    circles,
    teachers,
    schedules,
    attendance,
    assessmentDocs,
    taskDocs
  ) = await (
    ref.read(studentRepositoryProvider).getStudentsByCenter(centerId),
    ref.read(circleRepositoryProvider).getCirclesByCenter(centerId),
    ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId),
    ref.read(scheduleRepositoryProvider).getSchedulesByCenter(centerId),
    ref.read(attendanceRepositoryProvider).getByCenter(centerId),
    ds.query('memorization_records',
        where: [QueryFilter.equal('centerId', centerId)]),
    ds.query('learning_tasks',
        where: [QueryFilter.equal('centerId', centerId)]),
  ).wait;
  return ReportData(
    students: students,
    circles: circles,
    teachers: teachers,
    schedules: schedules,
    attendance: attendance,
    assessments: [
      for (final d in assessmentDocs)
        MemorizationRecord.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d))
    ],
    tasks: [
      for (final d in taskDocs)
        LearningTask.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d))
    ],
  );
});

enum _Kind { attendance, teachers, circles }

/// Director reports, computed from the center's own records for the chosen
/// period, with the filters used printed next to the result and a CSV copy.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Kind _kind = _Kind.attendance;
  int? _days = 30; // null = all time
  String? _circleId;

  ReportPeriod _period() {
    if (_days == null) return const ReportPeriod();
    final n = DateTime.now();
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    return ReportPeriod(
        from: tomorrow.subtract(Duration(days: _days!)), to: tomorrow);
  }

  String get _periodLabel => _days == null ? 'كل الفترات' : 'آخر $_days يومًا';

  Future<void> _copy(String csv) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('نُسخ التقرير بصيغة CSV. الصقه في جدول بيانات.'),
          backgroundColor: DesignTokens.success));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reportDataProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('التقارير'), centerTitle: false),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعذر تحميل بيانات التقارير'),
              const SizedBox(height: DesignTokens.space12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(reportDataProvider),
                  child: const Text('إعادة المحاولة')),
            ]),
          ),
          data: _body,
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }

  Widget _body(ReportData d) {
    final period = _period();
    final (title, headers, rows, note) = switch (_kind) {
      _Kind.attendance => () {
          final r = attendanceByStudent(d, period, circleId: _circleId);
          return (
            'الحضور حسب الطالب',
            ['الطالب', 'الحلقة', 'حاضر', 'متأخر', 'غائب', 'معذور', 'النسبة'],
            [
              for (final x in r)
                [
                  x.name,
                  x.circleName,
                  x.summary.present,
                  x.summary.late,
                  x.summary.absent,
                  x.summary.excused,
                  rateText(x.summary)
                ]
            ],
            'النسبة = (حاضر + متأخر) ÷ (حاضر + متأخر + غائب). لا يدخل المعذورون في المقام، '
                'والطالب بلا سجلات لا نسبة له (—) وليس 0%.',
          );
        }(),
      _Kind.teachers => () {
          final r = teacherActivity(d, period);
          return (
            'نشاط المعلمين',
            [
              'المعلم',
              'جلسات منجزة',
              'جلسات مجدولة',
              'سجلات حضور',
              'تسميعات',
              'مهام بانتظار التحقق'
            ],
            [
              for (final x in r)
                [
                  x.name,
                  x.sessionsCompleted,
                  x.sessionsScheduled,
                  x.attendanceRecorded,
                  x.assessments,
                  x.tasksAwaitingVerification
                ]
            ],
            'هذه أعداد عمل منجز وليست تقييمًا لجودة التدريس.',
          );
        }(),
      _Kind.circles => () {
          final r = circleOverview(d, period);
          return (
            'نظرة على الحلقات',
            [
              'الحلقة',
              'المعلم',
              'الطلاب',
              'السعة',
              'جلسات منجزة',
              'جلسات ملغاة',
              'نسبة الحضور'
            ],
            [
              for (final x in r)
                [
                  x.name,
                  x.teacherName,
                  x.students,
                  x.capacity,
                  x.sessionsCompleted,
                  x.sessionsCancelled,
                  rateText(x.summary)
                ]
            ],
            'عدد الطلاب والسعة حاليان؛ بقية الأعمدة ضمن الفترة المختارة.',
          );
        }(),
    };
    final csv = toCsv(headers, rows);

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Wrap(spacing: DesignTokens.space8, children: [
          for (final (k, label) in [
            (_Kind.attendance, 'الحضور'),
            (_Kind.teachers, 'المعلمون'),
            (_Kind.circles, 'الحلقات'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _kind == k,
              onSelected: (_) => setState(() => _kind = k),
            ),
        ]),
        const SizedBox(height: DesignTokens.space8),
        Wrap(spacing: DesignTokens.space8, children: [
          for (final (days, label) in [
            (7, '7 أيام'),
            (30, '30 يومًا'),
            (90, '90 يومًا'),
            (null, 'الكل'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _days == days,
              onSelected: (_) => setState(() => _days = days),
            ),
        ]),
        if (_kind == _Kind.attendance) ...[
          const SizedBox(height: DesignTokens.space8),
          DropdownButtonFormField<String?>(
            value: _circleId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الحلقة'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('كل الحلقات')),
              for (final c in d.circles)
                DropdownMenuItem<String?>(
                    value: c.circleId, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _circleId = v),
          ),
        ],
        const SizedBox(height: DesignTokens.space16),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(
          'الفترة: $_periodLabel'
          '${_kind == _Kind.attendance && _circleId != null ? ' • الحلقة: ${d.circles.firstWhere((c) => c.circleId == _circleId).name}' : ''}'
          ' • ${rows.length} صف',
          style: const TextStyle(color: DesignTokens.secondaryText),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(note,
            style: const TextStyle(
                fontSize: 12, color: DesignTokens.secondaryText, height: 1.5)),
        const SizedBox(height: DesignTokens.space8),
        OutlinedButton.icon(
          onPressed: rows.isEmpty ? null : () => _copy(csv),
          icon: const Icon(Icons.copy),
          label: const Text('نسخ بصيغة CSV'),
        ),
        const SizedBox(height: DesignTokens.space12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(DesignTokens.space24),
            child: Text('لا توجد بيانات لهذا الاختيار.',
                textAlign: TextAlign.center),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [for (final h in headers) DataColumn(label: Text(h))],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [for (final c in r) DataCell(Text('$c'))]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
