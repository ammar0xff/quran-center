import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/features/shared/level_summary.dart';
import 'package:quran_center/features/teacher/students/teacher_student_data.dart';
import 'package:quran_center/features/teacher/widgets/teacher_bottom_nav.dart';

/// The teacher's own students, searchable by name.
class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teacherStudentsProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('طلابي'), centerTitle: false),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل الطلاب'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(teacherStudentsProvider),
                    child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
          data: (d) {
            if (d.students.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(DesignTokens.space24),
                  child: Text('لم يُسند إليك طلاب بعد. تواصل مع إدارة الدار.',
                      textAlign: TextAlign.center),
                ),
              );
            }
            final q = _query.trim().toLowerCase();
            final items = d.students
                .where((s) =>
                    q.isEmpty ||
                    s.fullName.toLowerCase().contains(q) ||
                    (s.preferredName?.toLowerCase().contains(q) ?? false))
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.space16),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم'),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب مطابقون'))
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.space16),
                          children: [
                            for (final s in items)
                              Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: DesignTokens.softMint,
                                    child: Text(
                                      s.fullName.isNotEmpty ? s.fullName[0] : 'ط',
                                      style: const TextStyle(
                                          color: DesignTokens.primaryDarkGreen,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(s.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text([
                                        if ((d.circleNameOf[s.studentId] ?? '').isNotEmpty)
                                          d.circleNameOf[s.studentId]!,
                                        if ((d.openTasks[s.studentId] ?? 0) > 0)
                                          '${d.openTasks[s.studentId]} مهام مفتوحة',
                                      ].join(' • ')),
                                      LevelSummary(
                                        level: d.levels[s.studentId] ?? computeLevel(const []),
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_left),
                                  onTap: () => context.push('/teacher/students/${s.studentId}'),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: const TeacherBottomNav(currentIndex: 1),
      ),
    );
  }
}
