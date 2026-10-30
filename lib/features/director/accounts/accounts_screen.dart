import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/rosette.dart';
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

class _Accounts {
  const _Accounts(this.users, this.teacherEmails);
  final List<User> users;

  /// teacher uid -> the email their activation link goes to.
  final Map<String, String> teacherEmails;
}

final _accountsProvider = FutureProvider.autoDispose<_Accounts>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final (users, teachers) = await (
    ref.read(userRepositoryProvider).getAllUsersByCenter(centerId),
    ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId),
  ).wait;
  return _Accounts(users, {
    for (final t in teachers)
      if (t.contactInfo?['email'] != null)
        t.teacherId: t.contactInfo!['email']!,
  });
});

String roleLabel(UserRole r) {
  switch (r) {
    case UserRole.director:
      return 'مديرة/مدير';
    case UserRole.teacher:
      return 'معلم';
    case UserRole.student:
      return 'طالب';
    case UserRole.guardian:
      return 'ولي أمر';
  }
}

String accountStatusLabel(AccountStatus s) {
  switch (s) {
    case AccountStatus.active:
      return 'نشط';
    case AccountStatus.suspended:
      return 'معلّق';
    case AccountStatus.pending:
      return 'قيد التفعيل';
    case AccountStatus.incomplete:
      return 'ناقص';
  }
}

/// Every login in the center, by role and status. Suspending and reactivating
/// happen on the teacher list and the student profile (each with its own
/// confirmation); this screen is the overview and can re-send an activation
/// email to a teacher.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  UserRole? _role;
  AccountStatus? _status;
  String _query = '';

  Future<void> _resend(String email) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountAccessServiceProvider).resendActivation(email);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('أُرسلت رسالة التفعيل'),
            backgroundColor: DesignTokens.success));
    } on AccountAccessException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: DesignTokens.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_accountsProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('الحسابات'), centerTitle: false),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعذر تحميل الحسابات'),
              const SizedBox(height: DesignTokens.space12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(_accountsProvider),
                  child: const Text('إعادة المحاولة')),
            ]),
          ),
          data: (d) {
            final q = _query.trim().toLowerCase();
            final items = d.users.where((u) {
              if (_role != null && u.role != _role) return false;
              if (_status != null && u.status != _status) return false;
              return q.isEmpty || u.fullName.toLowerCase().contains(q);
            }).toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.space16),
                  child: Column(children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'ابحث بالاسم'),
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Wrap(spacing: DesignTokens.space8, children: [
                        for (final (r, label) in [
                          (null, 'كل الأدوار'),
                          (UserRole.director, 'الإدارة'),
                          (UserRole.teacher, 'المعلمون'),
                          (UserRole.student, 'الطلاب'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _role == r,
                            onSelected: (_) => setState(() => _role = r),
                          ),
                        for (final (s, label) in [
                          (null, 'كل الحالات'),
                          (AccountStatus.active, 'نشط'),
                          (AccountStatus.suspended, 'معلّق'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _status == s,
                            onSelected: (_) => setState(() => _status = s),
                          ),
                      ]),
                    ),
                  ]),
                ),
                Expanded(
                  child: items.isEmpty
                      ? EmptyState('لا توجد حسابات مطابقة')
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.space16),
                          children: [
                            for (final u in items)
                              Card(
                                child: ListTile(
                                  leading: Rosette(
                                      size: 42,
                                      color: DesignTokens.primaryDarkGreen,
                                      child: Text(
                                          u.fullName.characters.firstOrNull ??
                                              '',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800))),
                                  title: Text(u.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      '${roleLabel(u.role)} • ${accountStatusLabel(u.status)}'),
                                  trailing: _actions(u, d),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }

  Widget? _actions(User u, _Accounts d) {
    if (u.role == UserRole.teacher) {
      final email = d.teacherEmails[u.uid];
      return PopupMenuButton<String>(
        tooltip: 'خيارات',
        onSelected: (v) {
          if (v == 'open') context.push('/director/teachers');
          if (v == 'resend' && email != null) _resend(email);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('إدارة المعلمين')),
          if (email != null && u.status == AccountStatus.active)
            const PopupMenuItem(
                value: 'resend', child: Text('إعادة إرسال رسالة التفعيل')),
        ],
      );
    }
    if (u.role == UserRole.student && u.studentId != null) {
      return IconButton(
        tooltip: 'ملف الطالب',
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.push('/director/students/${u.studentId}'),
      );
    }
    return null;
  }
}
