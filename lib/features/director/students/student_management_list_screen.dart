import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Director student management list.
///
/// Searches by name / student ID, filters by enrollment status, circle,
/// teacher, account access, and follow-up requirement. Actions include open
/// profile, edit, assign circle, change teacher, enable/manage access,
/// archive/reinstate.
class StudentManagementListScreen extends ConsumerWidget {
  const StudentManagementListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentRepo = ref.watch(studentRepositoryProvider);
    final students = studentRepo.getStudentsByCenter(ref.read(centerIdProvider));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إدارة الطلاب'),
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
                  Text('إضافة طالب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Student>>(
          future: students,
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
              itemBuilder: (_, i) => _StudentCard(student: list[i]),
            );
          },
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: DesignTokens.secondaryText),
          const SizedBox(height: DesignTokens.space16),
          Text(
            'لا يوجد طلاب',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            'أضف طالبًا جديدًا لبدء إدارة السجل التعليمي.',
            style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.space24),
          FilledButton(
            onPressed: () {},
            child: const Text('إضافة طالب'),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  const _StudentCard({required this.student});

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
            student.fullName.isNotEmpty ? student.fullName[0] : 'ط',
            style: const TextStyle(
              color: DesignTokens.primaryDarkGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.displayName,
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
                    color: _statusColor(student.enrollmentStatus).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    border: Border.all(color: _statusColor(student.enrollmentStatus)),
                  ),
                  child: Text(
                    _statusLabel(student.enrollmentStatus),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(student.enrollmentStatus),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space8),
                Text(
                  student.accountMode == AccountMode.loginEnabled
                      ? 'دخول مفعّل'
                      : 'بدون دخول',
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
            const PopupMenuItem(value: 'assign_circle', child: Text('تعيين حلقة')),
            const PopupMenuItem(value: 'change_teacher', child: Text('تغيير المعلم')),
            const PopupMenuItem(value: 'access', child: Text('إدارة الدخول')),
            const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
          ],
        ),
      ),
    );
  }

  Color _statusColor(EnrollmentStatus s) {
    switch (s) {
      case EnrollmentStatus.active:
        return DesignTokens.success;
      case EnrollmentStatus.archived:
      case EnrollmentStatus.withdrawn:
        return DesignTokens.error;
      case EnrollmentStatus.completed:
      case EnrollmentStatus.transferred:
        return DesignTokens.secondaryText;
    }
  }

  String _statusLabel(EnrollmentStatus s) {
    switch (s) {
      case EnrollmentStatus.active:
        return 'منتظم';
      case EnrollmentStatus.archived:
        return 'مؤرشف';
      case EnrollmentStatus.withdrawn:
        return 'منسحب';
      case EnrollmentStatus.completed:
        return 'مكتمل';
      case EnrollmentStatus.transferred:
        return 'منقول';
    }
  }
}
