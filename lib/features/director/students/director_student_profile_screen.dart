import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';
import 'package:quran_center/design_system/components/section_header.dart';
import 'package:quran_center/features/director/students/account_access_tab.dart';

/// Director student profile — full educational + administrative view with tabs.
///
/// Tabs: Overview, Educational History, Learning Plans, Attendance, Enrollment,
/// Account Access, Audit History.
class DirectorStudentProfileScreen extends ConsumerWidget {
  final String studentId;
  const DirectorStudentProfileScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('ملف الطالب'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, size: 24),
              onPressed: () {},
            ),
          ],
        ),
        body: studentAsync.when(
          data: (student) {
            if (student == null) {
              return _buildNotFound(context);
            }
            return DefaultTabController(
              length: 7,
              child: Column(
                children: [
                  _buildHeader(context, student),
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'نظرة عامة'),
                      Tab(text: 'التعليمي'),
                      Tab(text: 'الخطط'),
                      Tab(text: 'الحضور'),
                      Tab(text: 'التسجيل'),
                      Tab(text: 'الدخول'),
                      Tab(text: 'سجل التدقيق'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildOverviewTab(student),
                        _buildHistoryTab(),
                        _buildPlansTab(),
                        _buildAttendanceTab(),
                        _buildEnrollmentTab(),
                        AccountAccessTab(
                          student: student,
                          onChanged: () => ref.invalidate(studentProvider(studentId)),
                        ),
                        _buildAuditTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return const Center(child: Text('الطالب غير موجود'));
  }

  Widget _buildHeader(BuildContext context, Student student) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DesignTokens.borders)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: DesignTokens.softMint,
                child: Text(
                  student.fullName.isNotEmpty ? student.fullName[0] : 'ط',
                  style: const TextStyle(
                    color: DesignTokens.primaryDarkGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.mainText,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space6),
                    Text(
                      'رقم الطالب: ${student.studentId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      'المستوى: ${student.educationalLevel}',
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space6,
                ),
                decoration: BoxDecoration(
                  color: _accountModeColor(student.accountMode).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                  border: Border.all(color: _accountModeColor(student.accountMode)),
                ),
                child: Text(
                  _accountModeLabel(student.accountMode),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accountModeColor(student.accountMode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Row(
            children: [
              _statItem('تاريخ التسجيل', DateFormat.yMMMMd('ar').format(student.createdAt)),
              const SizedBox(width: DesignTokens.space20),
              _statItem('الحالة', _statusLabel(student.enrollmentStatus)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DesignTokens.mainText,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Student student) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        SectionHeader(title: 'ملخص educativo', onSeeAll: () {}),
        const SizedBox(height: DesignTokens.space16),
        _infoCard([
          _infoRow('المعلم المخصص', 'لم يتم تعيين معلم بعد'),
          _infoRow('الحلقة الحالية', 'لم يتم تعيين حلقة بعد'),
          _infoRow('المهام النشطة', '0'),
          _infoRow('المهام المتأخرة', '0'),
        ]),
        const SizedBox(height: DesignTokens.space24),
        SectionHeader(title: 'المهام القادمة', onSeeAll: () {}),
        const SizedBox(height: DesignTokens.space16),
        _buildEmptyList('لا توجد مهام حالية', 'سيظهر هنا المهام المخصصة للطالب'),
      ],
    );
  }

  Widget _buildHistoryTab() => _buildEmptyList('لا يوجد سجل تعليمي بعد', '');
  Widget _buildPlansTab() => _buildEmptyList('لا توجد خطط تعليمية بعد', '');
  Widget _buildAttendanceTab() => _buildEmptyList('لا توجد سجلات حضور بعد', '');
  Widget _buildEnrollmentTab() => _buildEmptyList('لا يوجد سجل تسجيل بعد', '');
  Widget _buildAuditTab() => _buildEmptyList('لا توجد سجلات تدقيق بعد', '');


  Widget _buildEmptyList(String message, String hint) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: DesignTokens.secondaryText),
          const SizedBox(height: DesignTokens.space16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DesignTokens.mainText,
            ),
            textAlign: TextAlign.center,
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space8),
            Text(hint, style: TextStyle(fontSize: 13, color: DesignTokens.secondaryText), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Card(
      child: Column(
        children: rows
            .asMap()
            .entries
            .map((e) {
              final isLast = e.key == rows.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: DesignTokens.mainText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _accountModeColor(AccountMode m) {
    switch (m) {
      case AccountMode.none:
        return DesignTokens.secondaryText;
      case AccountMode.loginEnabled:
        return DesignTokens.success;
      case AccountMode.suspended:
        return DesignTokens.error;
    }
  }

  String _accountModeLabel(AccountMode m) {
    switch (m) {
      case AccountMode.none:
        return 'بدون دخول';
      case AccountMode.loginEnabled:
        return 'دخول مفعّل';
      case AccountMode.suspended:
        return 'مُعلَّق';
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

/// Provider to load a student by id (wired to repository).
final studentProvider = FutureProvider.family<Student?, String>((ref, id) async {
  return ref.read(studentRepositoryProvider).getStudent(id);
});
