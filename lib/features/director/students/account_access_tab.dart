import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';

String accessModeLabel(AccountMode m) {
  switch (m) {
    case AccountMode.none:
      return 'بدون دخول';
    case AccountMode.loginEnabled:
      return 'دخول مفعّل';
    case AccountMode.suspended:
      return 'الدخول معلّق';
  }
}

String accessBlockHint(AccessBlock b) {
  switch (b) {
    case AccessBlock.alreadyHasLogin:
      return 'لدى الطالب حساب دخول بالفعل';
    case AccessBlock.noLoginToChange:
      return 'لا يوجد حساب دخول لتغييره';
    case AccessBlock.notSuspended:
      return 'الدخول غير معلّق';
    case AccessBlock.alreadySuspended:
      return 'الدخول معلّق بالفعل';
    case AccessBlock.archivedStudent:
      return 'لا يمكن تفعيل الدخول لطالب مؤرشف';
    case AccessBlock.missingLink:
      return 'الحساب المرتبط غير موجود، راجع الدعم الفني';
  }
}

/// Account Access tab of the director student profile.
///
/// Enabling creates a login for the EXISTING student profile (no duplicate
/// profile). Suspending keeps all educational history. All account changes run
/// on the backend; this widget only requests them and refreshes afterwards.
class AccountAccessTab extends ConsumerStatefulWidget {
  const AccountAccessTab({
    super.key,
    required this.student,
    required this.onChanged,
  });

  final Student student;

  /// Called after the server confirmed a change so the caller can reload.
  final VoidCallback onChanged;

  @override
  ConsumerState<AccountAccessTab> createState() => _AccountAccessTabState();
}

class _AccountAccessTabState extends ConsumerState<AccountAccessTab> {
  bool _busy = false;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? DesignTokens.error : DesignTokens.success,
    ));
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      _snack(successMessage);
      widget.onChanged();
    } on ActivationEmailException catch (e) {
      // Account exists now; refresh so the UI reflects it, but warn.
      _snack(e.message, error: true);
      widget.onChanged();
    } on AccountAccessException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _EmailDialog(),
    );
    if (email == null) return;
    await _run(
      () => ref.read(accountAccessServiceProvider).enableStudentAccess(
            studentId: widget.student.studentId,
            email: email,
          ),
      'تم تفعيل الدخول وإرسال رسالة التفعيل',
    );
  }

  Future<void> _toggleSuspend(bool suspend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(suspend ? 'تعليق دخول الطالب؟' : 'إعادة تفعيل الدخول؟'),
          content: Text(suspend
              ? 'لن يتمكن الطالب من تسجيل الدخول. يبقى سجله التعليمي كما هو، '
                  'ويمكنك إعادة التفعيل في أي وقت.'
              : 'سيتمكن الطالب من تسجيل الدخول مجددًا إلى سجله الحالي.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(suspend ? 'تعليق' : 'إعادة التفعيل'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(accountAccessServiceProvider).setSuspended(
            studentId: widget.student.studentId,
            suspend: suspend,
          ),
      suspend ? 'تم تعليق الدخول' : 'تمت إعادة تفعيل الدخول',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final enableBlock = checkAccessAction(s, AccessAction.enable);
    final suspendBlock = checkAccessAction(s, AccessAction.suspend);
    final reactivateBlock = checkAccessAction(s, AccessAction.reactivate);

    Widget action({
      required String label,
      required AccessBlock? block,
      required VoidCallback onPressed,
      bool primary = false,
    }) {
      final button = primary
          ? FilledButton(
              onPressed: block == null && !_busy ? onPressed : null,
              child: Text(label))
          : OutlinedButton(
              onPressed: block == null && !_busy ? onPressed : null,
              child: Text(label));
      return Padding(
        padding: const EdgeInsets.only(bottom: DesignTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            button,
            if (block != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space4),
                child: Text(accessBlockHint(block),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: DesignTokens.secondaryText)),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الحالة الحالية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: DesignTokens.space12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نوع الوصول'),
                  trailing: Text(accessModeLabel(s.accountMode)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الحساب المرتبط'),
                  trailing: Text(s.authUserId ?? 'غير مرتبط'),
                ),
                if (s.accountMode == AccountMode.none)
                  const Padding(
                    padding: EdgeInsets.only(top: DesignTokens.space8),
                    child: Text(
                      'هذا الطالب يُدار بالكامل عبر المعلم والإدارة. الدخول اختياري '
                      'ولا يؤثر على سجله التعليمي.',
                      style: TextStyle(
                          fontSize: 13,
                          color: DesignTokens.secondaryText,
                          height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space16),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: DesignTokens.space12),
            child: LinearProgressIndicator(),
          ),
        action(
          label: 'تفعيل دخول الطالب',
          block: enableBlock,
          onPressed: _enable,
          primary: true,
        ),
        action(
          label: 'تعليق الدخول',
          block: suspendBlock,
          onPressed: () => _toggleSuspend(true),
        ),
        action(
          label: 'إعادة تفعيل الدخول',
          block: reactivateBlock,
          onPressed: () => _toggleSuspend(false),
        ),
      ],
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog();

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!isPlausibleEmail(value)) {
      setState(() => _error = 'أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تفعيل دخول الطالب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيُنشأ حساب مرتبط بالملف التعليمي الحالي، وتُرسل إلى هذا البريد '
              'رسالة لتعيين كلمة المرور.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: DesignTokens.space12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(onPressed: _submit, child: const Text('تفعيل')),
        ],
      ),
    );
  }
}
