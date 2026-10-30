import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Director circle list: search, teacher and enrolment per circle, archive.
class CircleManagementListScreen extends ConsumerStatefulWidget {
  const CircleManagementListScreen({super.key});

  @override
  ConsumerState<CircleManagementListScreen> createState() =>
      _CircleManagementListScreenState();
}

class _CircleManagementListScreenState
    extends ConsumerState<CircleManagementListScreen> {
  List<Circle> _circles = [];
  Map<String, String> _teacherNames = {};
  Map<String, int> _enrolled = {};
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final centerId = ref.read(centerIdProvider);
      final circles =
          await ref.read(circleRepositoryProvider).getCirclesByCenter(centerId);
      final teachers =
          await ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId);
      final enrollments = ref.read(enrollmentRepositoryProvider);
      final counts = <String, int>{};
      for (final c in circles) {
        counts[c.circleId] =
            (await enrollments.getActiveEnrollmentsForCircle(c.circleId, centerId: centerId)).length;
      }
      if (!mounted) return;
      setState(() {
        _circles = circles;
        _teacherNames = {for (final t in teachers) t.teacherId: t.fullName};
        _enrolled = counts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الحلقات';
      });
    }
  }

  List<Circle> get _visible {
    final q = _query.trim();
    final list = _circles.where((c) => q.isEmpty || c.name.contains(q)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _archive(Circle circle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('أرشفة «${circle.name}»؟'),
          content: const Text(
              'ستُخفى الحلقة من القوائم النشطة. يبقى سجل الطلاب والحضور والتقييمات كما هو.'),
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
    if (ok != true) return;
    try {
      await ref
          .read(circleRepositoryProvider)
          .archiveCircle(circle.circleId, actorId: ref.read(actorProvider).id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت أرشفة الحلقة'),
          backgroundColor: DesignTokens.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذرت الأرشفة. حاول مرة أخرى.'),
          backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إدارة الحلقات'),
          centerTitle: false,
          actions: [
            FilledButton.icon(
              onPressed: () => context.push('/director/circles/add'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('إنشاء حلقة'),
            ),
            const SizedBox(width: DesignTokens.space12),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: DesignTokens.space12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : _circles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_outlined,
                                size: 64, color: DesignTokens.secondaryText),
                            const SizedBox(height: DesignTokens.space16),
                            const Text('لا توجد حلقات',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: DesignTokens.space8),
                            const Text('أنشئ حلقة لبدء توزيع الطلاب والمعلمين.',
                                style: TextStyle(color: DesignTokens.secondaryText)),
                            const SizedBox(height: DesignTokens.space24),
                            FilledButton(
                              onPressed: () => context.push('/director/circles/add'),
                              child: const Text('إنشاء أول حلقة'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(DesignTokens.space16),
                            child: TextField(
                              onChanged: (v) => setState(() => _query = v),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'ابحث باسم الحلقة',
                              ),
                            ),
                          ),
                          Expanded(
                            child: items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('لا توجد حلقات مطابقة'),
                                        TextButton(
                                          onPressed: () => setState(() => _query = ''),
                                          child: const Text('مسح البحث'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: items.length,
                                    itemBuilder: (_, i) => _CircleCard(
                                      circle: items[i],
                                      teacherName: _teacherNames[items[i].assignedTeacherId],
                                      enrolled: _enrolled[items[i].circleId] ?? 0,
                                      onArchive: () => _archive(items[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 3),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({
    required this.circle,
    required this.teacherName,
    required this.enrolled,
    required this.onArchive,
  });

  final Circle circle;
  final String? teacherName;
  final int enrolled;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final active = circle.status == CircleStatus.active;
    final color = active ? DesignTokens.success : DesignTokens.secondaryText;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space20, vertical: DesignTokens.space8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16, vertical: DesignTokens.space8),
        leading: const CircleAvatar(
          backgroundColor: DesignTokens.softMint,
          child: Icon(Icons.school, color: DesignTokens.primaryDarkGreen),
        ),
        title: Text(circle.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space4),
          child: Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(active ? 'نشطة' : 'مؤرشفة',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              Text('الطلاب $enrolled/${circle.maxCapacity}',
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
              Text(teacherName ?? 'بدون معلم',
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
              Text('${circle.weeklySchedule.length} جلسة أسبوعيًا',
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'خيارات',
          onSelected: (v) {
            if (v == 'assign') context.push('/director/enrollments/assign');
            if (v == 'archive') onArchive();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'assign', child: Text('تعيين طالب')),
            if (active) const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
          ],
        ),
      ),
    );
  }
}
