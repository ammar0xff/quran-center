import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Director circle management list.
///
/// Lists circles with level, assigned teacher, student count, capacity, weekly
/// schedule, status. Actions: open details, edit, manage students, manage
/// schedule, archive. Create Circle via header action.
class CircleManagementListScreen extends ConsumerWidget {
  const CircleManagementListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(circleRepositoryProvider).getCirclesByCenter('center-1');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إدارة الحلقات'),
          centerTitle: false,
          actions: [
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.primaryDarkGreen,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 6),
                  Text('إنشاء حلقة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Circle>>(
          future: circles,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('خطأ: ${snap.error}'));
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return _buildEmptyState(context);
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => _CircleCard(circle: list[i]),
            );
          },
        ),
        bottomNavigationBar: CustomBottomNav(
          items: const [
            BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard, activeIcon: Icons.dashboard),
            BottomNavItem(label: 'الطلاب', icon: Icons.people, activeIcon: Icons.people),
            BottomNavItem(label: 'المعلمون', icon: Icons.person, activeIcon: Icons.person),
            BottomNavItem(label: 'الحلقات', icon: Icons.school, activeIcon: Icons.school),
            BottomNavItem(label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu),
          ],
          currentIndex: 3,
          onTap: (i) {},
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school_outlined, size: 64, color: DesignTokens.secondaryText),
          const SizedBox(height: DesignTokens.space16),
          Text(
            'لا توجد حلقات',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            'أنشئ حلقة لبدء توزيع الطلاب والمعلمين.',
            style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.space24),
          FilledButton(
            onPressed: () {},
            child: const Text('إنشاء حلقة'),
          ),
        ],
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Circle circle;
  const _CircleCard({required this.circle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space20,
        vertical: DesignTokens.space8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space8,
        ),
        leading: CircleAvatar(
          backgroundColor: DesignTokens.softMint,
          child: const Icon(Icons.school, color: DesignTokens.primaryDarkGreen, size: 24),
        ),
        title: Text(
          circle.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DesignTokens.mainText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: DesignTokens.space4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space8,
                    vertical: DesignTokens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.primaryDarkGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    border: Border.all(color: DesignTokens.primaryDarkGreen),
                  ),
                  child: Text(
                    circle.status == CircleStatus.active ? 'نشطة' : 'مؤرشفة',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.primaryDarkGreen,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space8),
                Text(
                  '${circle.weeklySchedule.length} جلسة/أسبوع • ${circle.sessionDurationMinutes} دقيقة',
                  style: TextStyle(
                    fontSize: 11,
                    color: DesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {},
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'details', child: Text('عرض التفاصيل')),
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'manage_students', child: Text('إدارة الطلاب')),
            const PopupMenuItem(value: 'manage_schedule', child: Text('إدارة الجدول')),
            const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
          ],
        ),
      ),
    );
  }
}
