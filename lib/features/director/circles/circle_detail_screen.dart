import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/circle_service.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

const _dayNames = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

/// A circle's details and current students, with edit, add-student and
/// archive actions.
class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  Future<void> _archive(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('أرشفة «$name»؟'),
          content: const Text(
              'ستُخفى الحلقة من القوائم النشطة. يبقى سجل الطلاب والحضور كما هو.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('أرشفة')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final actor = ref.read(actorProvider);
      await ref.read(circleServiceProvider).archive(circleId,
          centerId: ref.read(centerIdProvider),
          actorId: actor.id,
          actorRole: actor.role);
      ref.invalidate(circleDetailProvider(circleId));
      messenger.showSnackBar(const SnackBar(
          content: Text('تمت أرشفة الحلقة'), backgroundColor: DesignTokens.success));
    } on CircleException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: DesignTokens.error));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('تعذرت الأرشفة. حاول مرة أخرى.'),
          backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(circleDetailProvider(circleId));
    final data = async.valueOrNull;
    final active = data?.circle.status == CircleStatus.active;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('تفاصيل الحلقة'),
          centerTitle: false,
          actions: [
            if (data != null && active)
              IconButton(
                tooltip: 'تعديل الحلقة',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await context.push('/director/circles/$circleId/edit');
                  ref.invalidate(circleDetailProvider(circleId));
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
                const Text('تعذر تحميل الحلقة'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(circleDetailProvider(circleId)),
                    child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
          data: (d) {
            if (d == null) return const Center(child: Text('الحلقة غير موجودة'));
            final c = d.circle;
            return ListView(
              padding: const EdgeInsets.all(DesignTokens.space20),
              children: [
                Text(c.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: DesignTokens.space4),
                Text(active ? 'نشطة' : 'مؤرشفة',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: active ? DesignTokens.success : DesignTokens.secondaryText)),
                const SizedBox(height: DesignTokens.space16),
                Card(
                  child: Column(children: [
                    _row('المعلم', d.teacherName ?? (c.assignedTeacherId == null ? 'بدون معلم' : '—')),
                    const Divider(height: 1),
                    _row('المستوى', c.educationalLevel.isEmpty ? '—' : c.educationalLevel),
                    const Divider(height: 1),
                    _row('النمط', circleModeLabel(c.locationOrMode)),
                    const Divider(height: 1),
                    _row('السعة', '${d.roster.length} / ${c.maxCapacity}'),
                    const Divider(height: 1),
                    _row('مدة الجلسة', '${c.sessionDurationMinutes} دقيقة'),
                    const Divider(height: 1),
                    _row(
                      'الجدول الأسبوعي',
                      c.weeklySchedule.isEmpty
                          ? 'لم يُحدَّد'
                          : c.weeklySchedule
                              .map((w) =>
                                  '${_dayNames[w.dayOfWeek] ?? w.dayOfWeek} ${w.startTime}–${w.endTime}')
                              .join('\n'),
                    ),
                    if (c.description != null) ...[
                      const Divider(height: 1),
                      _row('الوصف', c.description!),
                    ],
                  ]),
                ),
                const SizedBox(height: DesignTokens.space24),
                Row(
                  children: [
                    Expanded(
                      child: Text('الطلاب (${d.roster.length})',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    if (active)
                      TextButton.icon(
                        onPressed: () async {
                          await context
                              .push('/director/enrollments/assign?circle=$circleId');
                          ref.invalidate(circleDetailProvider(circleId));
                        },
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('إضافة طالب'),
                      ),
                  ],
                ),
                if (d.roster.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
                    child: Text('لا يوجد طلاب في هذه الحلقة بعد.',
                        style: TextStyle(color: DesignTokens.secondaryText)),
                  )
                else
                  for (final r in d.roster)
                    Card(
                      child: ListTile(
                        title: Text(r.student?.displayName ?? 'طالب غير معروف'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: r.student == null
                            ? null
                            : () => context.push('/director/students/${r.student!.studentId}'),
                      ),
                    ),
                if (active) ...[
                  const SizedBox(height: DesignTokens.space24),
                  OutlinedButton.icon(
                    onPressed: () => _archive(context, ref, c.name),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('أرشفة الحلقة'),
                  ),
                ],
              ],
            );
          },
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 3),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(
            vertical: DesignTokens.space12, horizontal: DesignTokens.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: DesignTokens.secondaryText)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
