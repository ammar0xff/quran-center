import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

class _TeacherCircles {
  const _TeacherCircles(this.circles, this.studentCounts);
  final List<Circle> circles;
  final Map<String, int> studentCounts;
}

final _teacherCirclesProvider =
    FutureProvider.autoDispose<_TeacherCircles>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final teacherId = ref.watch(actorProvider).id;
  final ws = ref.read(teacherWorkspaceProvider);
  final (circles, enrollments) = await (
    ws.circles(centerId, teacherId),
    ws.activeEnrollments(centerId, teacherId),
  ).wait;
  final counts = <String, int>{};
  for (final e in enrollments) {
    counts[e.circleId] = (counts[e.circleId] ?? 0) + 1;
  }
  final active = circles.where((c) => c.status == CircleStatus.active).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return _TeacherCircles(active, counts);
});

/// The circles assigned to the signed-in teacher.
class TeacherCirclesScreen extends ConsumerWidget {
  const TeacherCirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_teacherCirclesProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('حلقاتي'), centerTitle: false),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل الحلقات'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(_teacherCirclesProvider),
                    child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
          data: (d) {
            if (d.circles.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(DesignTokens.space24),
                  child: Text('لم تُسند إليك حلقات بعد. تواصل مع إدارة الدار.',
                      textAlign: TextAlign.center),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(DesignTokens.space16),
              children: [
                for (final c in d.circles)
                  Card(
                    child: ListTile(
                      leading: const Rosette(
                          size: 44,
                          color: DesignTokens.leaf,
                          child: Icon(Icons.school_rounded,
                              color: Colors.white, size: 20)),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${d.studentCounts[c.circleId] ?? 0} طالب • ${circleModeLabel(c.locationOrMode)}'
                          '${c.educationalLevel.isEmpty ? '' : ' • ${c.educationalLevel}'}'),
                    ),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 2),
      ),
    );
  }
}
