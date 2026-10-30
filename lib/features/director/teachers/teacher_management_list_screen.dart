import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Director teacher list: search, status filter, suspend / reactivate.
class TeacherManagementListScreen extends ConsumerStatefulWidget {
  const TeacherManagementListScreen({super.key});

  @override
  ConsumerState<TeacherManagementListScreen> createState() =>
      _TeacherManagementListScreenState();
}

class _TeacherManagementListScreenState
    extends ConsumerState<TeacherManagementListScreen> {
  List<Teacher> _teachers = [];
  String _query = '';
  AccountStatus? _status;
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
          .read(teacherRepositoryProvider)
          .getTeachersByCenter(ref.read(centerIdProvider));
      if (!mounted) return;
      setState(() {
        _teachers = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المعلمين';
      });
    }
  }

  List<Teacher> get _visible {
    final q = _query.trim().toLowerCase();
    final list = _teachers.where((t) {
      if (_status != null && t.status != _status) return false;
      return q.isEmpty || t.fullName.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  Future<void> _toggleSuspend(Teacher t) async {
    final suspend = t.status == AccountStatus.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(suspend ? 'تعليق ${t.fullName}؟' : 'إعادة تفعيل ${t.fullName}؟'),
          content: Text(suspend
              ? 'لن يتمكن المعلم من تسجيل الدخول. تبقى سجلاته وتقييماته كما هي، '
                  'ويمكنك إعادة التفعيل في أي وقت.'
              : 'سيتمكن المعلم من تسجيل الدخول مجددًا.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(suspend ? 'تعليق' : 'إعادة التفعيل')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(accountAccessServiceProvider)
          .setTeacherSuspended(teacherId: t.teacherId, suspend: suspend);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(suspend ? 'تم تعليق المعلم' : 'تمت إعادة تفعيل المعلم'),
          backgroundColor: DesignTokens.success));
    } on AccountAccessException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: DesignTokens.error));
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
          title: const Text('إدارة المعلمين'),
          centerTitle: false,
          actions: [
            FilledButton.icon(
              onPressed: () => context.push('/director/teachers/add'),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('إضافة معلم'),
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
                : _teachers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 64, color: DesignTokens.secondaryText),
                            const SizedBox(height: DesignTokens.space16),
                            const Text('لا يوجد معلمون',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: DesignTokens.space8),
                            const Text('أضف معلمًا لبدء تعيين الحلقات والطلاب.',
                                style: TextStyle(color: DesignTokens.secondaryText)),
                            const SizedBox(height: DesignTokens.space24),
                            FilledButton(
                              onPressed: () => context.push('/director/teachers/add'),
                              child: const Text('إضافة أول معلم'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(DesignTokens.space16),
                            child: Column(
                              children: [
                                TextField(
                                  onChanged: (v) => setState(() => _query = v),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'ابحث باسم المعلم',
                                  ),
                                ),
                                const SizedBox(height: DesignTokens.space8),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Wrap(
                                    spacing: DesignTokens.space8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('الكل'),
                                        selected: _status == null,
                                        onSelected: (_) => setState(() => _status = null),
                                      ),
                                      ChoiceChip(
                                        label: const Text('نشط'),
                                        selected: _status == AccountStatus.active,
                                        onSelected: (_) => setState(
                                            () => _status = AccountStatus.active),
                                      ),
                                      ChoiceChip(
                                        label: const Text('معلّق'),
                                        selected: _status == AccountStatus.suspended,
                                        onSelected: (_) => setState(
                                            () => _status = AccountStatus.suspended),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('لا يوجد معلمون مطابقون'),
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _query = '';
                                            _status = null;
                                          }),
                                          child: const Text('مسح البحث والفلاتر'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: items.length,
                                    itemBuilder: (_, i) => _TeacherCard(
                                      teacher: items[i],
                                      onToggleSuspend: () => _toggleSuspend(items[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 2),
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.onToggleSuspend});

  final Teacher teacher;
  final VoidCallback onToggleSuspend;

  @override
  Widget build(BuildContext context) {
    final active = teacher.status == AccountStatus.active;
    final suspended = teacher.status == AccountStatus.suspended;
    final label = switch (teacher.status) {
      AccountStatus.active => 'نشط',
      AccountStatus.suspended => 'معلّق',
      AccountStatus.pending => 'قيد التفعيل',
      AccountStatus.incomplete => 'ناقص',
    };
    final color = active
        ? DesignTokens.success
        : suspended
            ? DesignTokens.error
            : DesignTokens.warning;
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
        leading: CircleAvatar(
          backgroundColor: DesignTokens.softMint,
          child: Text(
            teacher.fullName.isNotEmpty ? teacher.fullName[0] : 'م',
            style: const TextStyle(
                color: DesignTokens.primaryDarkGreen, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(teacher.fullName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space4),
          child: Wrap(
            spacing: DesignTokens.space8,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              Text(
                teacher.assignedCircleIds.isEmpty
                    ? 'بدون حلقات'
                    : '${teacher.assignedCircleIds.length} حلقة',
                style: const TextStyle(
                    fontSize: 12, color: DesignTokens.secondaryText),
              ),
            ],
          ),
        ),
        trailing: (active || suspended)
            ? PopupMenuButton<String>(
                tooltip: 'خيارات',
                onSelected: (_) => onToggleSuspend(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(active ? 'تعليق الدخول' : 'إعادة تفعيل')),
                ],
              )
            : null,
      ),
    );
  }
}
