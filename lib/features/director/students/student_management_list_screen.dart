import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/student_filter.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

String enrollmentStatusLabel(EnrollmentStatus s) {
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

Color enrollmentStatusColor(EnrollmentStatus s) {
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

String accessLabel(AccountMode m) {
  switch (m) {
    case AccountMode.none:
      return 'بدون دخول';
    case AccountMode.loginEnabled:
      return 'دخول مفعّل';
    case AccountMode.suspended:
      return 'الدخول معلّق';
  }
}

/// Director student list: search by name or id, status and login filters,
/// open profile, assign to a circle, archive / reinstate.
class StudentManagementListScreen extends ConsumerStatefulWidget {
  const StudentManagementListScreen({super.key});

  @override
  ConsumerState<StudentManagementListScreen> createState() =>
      _StudentManagementListScreenState();
}

class _StudentManagementListScreenState
    extends ConsumerState<StudentManagementListScreen> {
  List<Student> _students = [];
  String _query = '';
  EnrollmentStatus? _status = EnrollmentStatus.active;
  AccessFilter _access = AccessFilter.any;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(studentRepositoryProvider)
          .getStudentsByCenter(ref.read(centerIdProvider));
      if (!mounted) return;
      setState(() {
        _students = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الطلاب';
      });
    }
  }

  void _clearFilters() => setState(() {
        _query = '';
        _status = null;
        _access = AccessFilter.any;
      });

  Future<void> _toggleArchive(Student s) async {
    final archiving = s.enrollmentStatus == EnrollmentStatus.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(archiving
              ? 'أرشفة ${s.displayName}؟'
              : 'إعادة تفعيل ${s.displayName}؟'),
          content: Text(archiving
              ? 'يُنقل الطالب إلى الأرشيف. يبقى سجله الكامل من حضور وتقييمات، '
                  'ويمكنك إعادة تفعيله لاحقًا.'
              : 'يعود الطالب إلى قائمة الطلاب المنتظمين.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(archiving ? 'أرشفة' : 'إعادة التفعيل')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final actor = ref.read(actorProvider);
      final repo = ref.read(studentRepositoryProvider);
      if (archiving) {
        await repo.archiveStudent(s.studentId,
            actorId: actor.id, actorRole: actor.role);
      } else {
        await repo.reinstateStudent(s.studentId,
            actorId: actor.id, actorRole: actor.role);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(archiving ? 'تمت أرشفة الطالب' : 'تمت إعادة تفعيل الطالب'),
          backgroundColor: DesignTokens.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تنفيذ الإجراء. حاول مرة أخرى.'),
          backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = filterStudents(_students,
        query: _query, status: _status, access: _access);
    final filtering = _query.trim().isNotEmpty ||
        _status != null ||
        _access != AccessFilter.any;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(
          title: const Text('إدارة الطلاب'),
          centerTitle: false,
          actions: [
            FilledButton.icon(
              onPressed: () => context.push('/director/students/add'),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('إضافة طالب'),
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
                            onPressed: _load,
                            child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : _students.isEmpty
                    ? _emptyNoStudents()
                    : Column(
                        children: [
                          _filters(),
                          Expanded(
                            child: items.isEmpty
                                ? _emptyNoMatches(filtering)
                                : ListView.builder(
                                    itemCount: items.length,
                                    itemBuilder: (_, i) => _StudentCard(
                                      student: items[i],
                                      onOpen: () => context.push(
                                          '/director/students/${items[i].studentId}'),
                                      onAssign: () => context.push(
                                          '/director/enrollments/assign?student=${items[i].studentId}'),
                                      onToggleArchive: () =>
                                          _toggleArchive(items[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }

  Widget _filters() {
    Widget statusChip(String label, EnrollmentStatus? value) => ChoiceChip(
          label: Text(label),
          selected: _status == value,
          onSelected: (_) => setState(() => _status = value),
        );
    Widget accessChip(String label, AccessFilter value) => ChoiceChip(
          label: Text(label),
          selected: _access == value,
          onSelected: (_) => setState(() => _access = value),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.space16,
          DesignTokens.space12, DesignTokens.space16, DesignTokens.space4),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث بالاسم أو رقم الطالب',
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: DesignTokens.space8,
              children: [
                statusChip('الكل', null),
                statusChip('منتظم', EnrollmentStatus.active),
                statusChip('مؤرشف', EnrollmentStatus.archived),
                accessChip('أي دخول', AccessFilter.any),
                accessChip('بدون دخول', AccessFilter.noLogin),
                accessChip('لديه دخول', AccessFilter.hasLogin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNoStudents() => EmptyState(
        'أضف طالبًا جديدًا لبدء إدارة السجل التعليمي.',
        icon: Icons.people_alt_rounded,
        title: 'لا يوجد طلاب',
        action: FilledButton(
          onPressed: () => context.push('/director/students/add'),
          child: const Text('إضافة أول طالب'),
        ),
      );

  Widget _emptyNoMatches(bool filtering) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لا يوجد طلاب مطابقون',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (filtering)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('مسح البحث والفلاتر'),
              ),
          ],
        ),
      );
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onOpen,
    required this.onAssign,
    required this.onToggleArchive,
  });

  final Student student;
  final VoidCallback onOpen;
  final VoidCallback onAssign;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final color = enrollmentStatusColor(student.enrollmentStatus);
    final isActive = student.enrollmentStatus == EnrollmentStatus.active;
    final isArchived = student.enrollmentStatus == EnrollmentStatus.archived;
    // Material (not a colored DecoratedBox) so the tap ripple is visible.
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space20, vertical: DesignTokens.space8),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          side: const BorderSide(color: DesignTokens.borders),
        ),
        child: ListTile(
          onTap: onOpen,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space16, vertical: DesignTokens.space8),
          leading: Rosette(
              size: 44,
              color: DesignTokens.primaryDarkGreen,
              child: Text(
                  student.fullName.isNotEmpty ? student.fullName[0] : 'ط',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17))),
          title: Text(student.displayName,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space4),
            child: Wrap(
              spacing: DesignTokens.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Status is conveyed by text, never by color alone.
                Text(enrollmentStatusLabel(student.enrollmentStatus),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(accessLabel(student.accountMode),
                    style: const TextStyle(
                        fontSize: 12, color: DesignTokens.secondaryText)),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'خيارات',
            onSelected: (v) {
              if (v == 'open') onOpen();
              if (v == 'assign') onAssign();
              if (v == 'toggle') onToggleArchive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'open', child: Text('فتح الملف الشخصي')),
              if (isActive)
                const PopupMenuItem(
                    value: 'assign', child: Text('تعيين لحلقة')),
              if (isActive)
                const PopupMenuItem(value: 'toggle', child: Text('أرشفة')),
              if (isArchived)
                const PopupMenuItem(
                    value: 'toggle', child: Text('إعادة تفعيل')),
            ],
          ),
        ),
      ),
    );
  }
}
