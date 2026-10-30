import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/supervision.dart';
import 'package:quran_center/features/director/reports/reports_screen.dart'
    show reportDataProvider;
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Things worth a look, with the facts that put each one here. This points at
/// records; it does not rate students or teachers.
class SupervisionScreen extends ConsumerWidget {
  const SupervisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportDataProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(
            title: const Text('المتابعة التعليمية'), centerTitle: false),
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
          data: (d) {
            final items = followUps(d, DateTime.now());
            return ListView(
              padding: const EdgeInsets.all(DesignTokens.space16),
              children: [
                Card(
                  color: DesignTokens.softMint,
                  child: const Padding(
                    padding: EdgeInsets.all(DesignTokens.space12),
                    child: Text(
                      'تظهر هنا حالات محددة بقواعد واضحة: مهام تجاوزت موعدها، تدريب لم يتحقق منه المعلم '
                      'لأكثر من $awaitingVerificationDays أيام، غياب $repeatedAbsenceThreshold مرات أو أكثر '
                      'في آخر $repeatedAbsenceWindow جلسات مسجّلة (دون المعذورين)، وجلسات انتهت بلا سجل حضور. '
                      'هي إشارات لمراجعة السجلات وليست حكمًا على أحد.',
                      style: TextStyle(height: 1.6),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const EmptyState('لا توجد بنود للمتابعة الآن.',
                      icon: Icons.check_circle_outline_rounded),
                for (final kind in FollowUpKind.values)
                  ..._section(context, kind,
                      items.where((i) => i.kind == kind).toList()),
              ],
            );
          },
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }

  List<Widget> _section(
      BuildContext context, FollowUpKind kind, List<FollowUpItem> items) {
    if (items.isEmpty) return const [];
    return [
      SectionTitle('${followUpKindLabel(kind)} (${items.length})'),
      for (final i in items)
        Card(
          child: ListTile(
            title: Text(i.studentName ?? i.circleName ?? ''),
            subtitle: Text([
              i.reason,
              if (i.studentName != null && i.circleName != null) i.circleName!,
              if (i.teacherName != null) 'المعلم: ${i.teacherName}',
              DateFormat.yMMMd('ar').format(i.date),
            ].join(' • ')),
            isThreeLine: true,
            trailing:
                i.studentId == null ? null : const Icon(Icons.chevron_left),
            onTap: i.studentId == null
                ? null
                : () => context.push('/director/students/${i.studentId}'),
          ),
        ),
    ];
  }
}
