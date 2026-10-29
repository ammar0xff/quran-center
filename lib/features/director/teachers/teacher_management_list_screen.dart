import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Director teacher management list.
///
/// Lists teachers in the center with status, assigned circles, student count.
/// Actions: open profile, edit, assign circles, reassign students, suspend,
/// reactivate. Add Teacher via the header action.
class TeacherManagementListScreen extends ConsumerWidget {
  const TeacherManagementListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = ref.watch(teacherRepositoryProvider).getTeachersByCenter('center-1');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إدارة المعلمين'),
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
                  Icon(Icons.person_add, size: 20),
                  SizedBox(width: 6),
                  Text('إضافة معلم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Teacher>>(
          future: teachers,
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
              itemBuilder: (_, i) => _TeacherCard(teacher: list[i]),
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
          currentIndex: 2,
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
          const Icon(Icons.person_outline, size: 64, color: DesignTokens.secondaryText),
          const SizedBox(height: DesignTokens.space16),
          Text(
            'لا يوجد معلمون',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            'أضف معلمًا لبدء تعيين الحلقات والطلاب.',
            style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.space24),
          FilledButton(
            onPressed: () {},
            child: const Text('إضافة معلم'),
          ),
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;
  const _TeacherCard({required this.teacher});

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
          child: Text(
            teacher.fullName.isNotEmpty ? teacher.fullName[0] : 'م',
            style: const TextStyle(
              color: DesignTokens.primaryDarkGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          teacher.fullName,
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
                    color: _statusColor(teacher.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    border: Border.all(color: _statusColor(teacher.status)),
                  ),
                  child: Text(
                    _statusLabel(teacher.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(teacher.status),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space8),
                Text(
                  teacher.assignedCircleIds.isEmpty
                      ? 'بدون حلقات'
                      : '${teacher.assignedCircleIds.length} حلقة',
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
            const PopupMenuItem(value: 'open', child: Text('فتح الملف الشخصي')),
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'assign_circles', child: Text('تعيين حلقات')),
            const PopupMenuItem(value: 'reassign', child: Text('إعادة توزيع الطلاب')),
            const PopupMenuItem(value: 'suspend', child: Text('تعليق الدخول')),
            const PopupMenuItem(value: 'reactivate', child: Text('إعادة تفعيل')),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AccountStatus s) {
    switch (s) {
      case AccountStatus.active:
        return DesignTokens.success;
      case AccountStatus.suspended:
        return DesignTokens.error;
      case AccountStatus.pending:
        return DesignTokens.warning;
      case AccountStatus.incomplete:
        return DesignTokens.secondaryText;
    }
  }

  String _statusLabel(AccountStatus s) {
    switch (s) {
      case AccountStatus.active:
        return 'نشط';
      case AccountStatus.suspended:
        return 'مُعلَّق';
      case AccountStatus.pending:
        return 'قيد الانتظار';
      case AccountStatus.incomplete:
        return 'ناقص';
    }
  }
}
