import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/level_reports.dart';
import 'package:quran_center/features/director/reports/reports_screen.dart'
    show reportDataProvider;
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';
import 'package:quran_center/features/shared/level_summary.dart';

/// The level of every student and a summary per teacher, all computed from the
/// marks (ممتاز … إعادة) teachers gave to wirds.
class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportDataProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: DesignTokens.warmOffWhite,
          appBar: AppBar(
            title: const Text('المستويات'),
            centerTitle: false,
            bottom: const TabBar(
                tabs: [Tab(text: 'الطلاب'), Tab(text: 'المعلمون')]),
          ),
          body: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذر تحميل البيانات'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(reportDataProvider),
                    child: const Text('إعادة المحاولة')),
              ]),
            ),
            data: (d) => TabBarView(children: [
              _Students(rows: studentLevels(d)),
              _Teachers(rows: teacherLevels(d)),
            ]),
          ),
          bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
        ),
      ),
    );
  }
}

class _Students extends StatefulWidget {
  const _Students({required this.rows});
  final List<StudentLevelRow> rows;

  @override
  State<_Students> createState() => _StudentsState();
}

class _StudentsState extends State<_Students> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.rows.where((r) => r.name.contains(_q.trim())).toList();
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        const Text(
          'المستوى من آخر 12 وردًا مُقيَّمًا لكل طالب، أيًّا كانت المعلمة التي سمعت منه. '
          'الأضعف أولًا، ومن لم يُقيَّم له ورد في الآخر.',
          style: TextStyle(
              fontSize: 12, color: DesignTokens.secondaryText, height: 1.5),
        ),
        const SizedBox(height: DesignTokens.space8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم'),
        ),
        const SizedBox(height: DesignTokens.space8),
        if (items.isEmpty) const Center(child: Text('لا يوجد طلاب مطابقون')),
        for (final r in items)
          Card(
            child: ListTile(
              title: Text(r.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text([
                    if (r.circleName.isNotEmpty) r.circleName,
                    if (r.teacherNames.isNotEmpty)
                      'المعلمة: ${r.teacherNames.join('، ')}',
                    if (r.level.lastHeard != null)
                      'آخر ورد: ${DateFormat.MMMd('ar').format(r.level.lastHeard!)}',
                  ].join(' • ')),
                  const SizedBox(height: DesignTokens.space4),
                  LevelSummary(level: r.level, compact: true),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/director/students/${r.studentId}'),
            ),
          ),
      ],
    );
  }
}

class _Teachers extends StatelessWidget {
  const _Teachers({required this.rows});
  final List<TeacherLevelRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('لا يوجد معلمون.'));
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        const Text(
          '«مستوى طلابها» هو متوسط مستويات طلاب المعلمة الحاليين. «متوسط ما أعطته» هو متوسط '
          'التقدير الذي منحته لما سمعته (ويشمل الطلاب الزائرين). الرقمان وصف للأعمال المسجلة، '
          'وليسا حكمًا على جودة التدريس.',
          style: TextStyle(
              fontSize: 12, color: DesignTokens.secondaryText, height: 1.5),
        ),
        const SizedBox(height: DesignTokens.space8),
        for (final r in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                      'عدد طلابها: ${r.students} (لهم مستوى: ${r.studentsWithLevel})'),
                  Text('مستوى طلابها: ${averageText(r.studentsAverage)}'),
                  Text('أوراد سمعتها: ${r.wirdsHeard}'),
                  Text('متوسط ما أعطته: ${averageText(r.gradeGiven)}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
