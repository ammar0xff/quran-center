import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';

/// Requests a password-reset email. The confirmation is the same whether or
/// not the address belongs to an account, so it cannot be used to discover
/// who has one.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authGatewayProvider).sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('استعادة كلمة المرور')),
        body: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: _sent ? _confirmation(context) : _form(),
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read,
              size: 56, color: DesignTokens.success),
          const SizedBox(height: DesignTokens.space16),
          const Text(
            'إذا كان هذا البريد مسجلًا لدينا، فقد أرسلنا إليه رابطًا '
            'لإعادة تعيين كلمة المرور.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: DesignTokens.space24),
          FilledButton(
            onPressed: () => context.go(Routes.login),
            child: const Text('العودة إلى تسجيل الدخول'),
          ),
        ],
      );

  Widget _form() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'أدخل بريدك الإلكتروني وسنرسل إليك رابطًا لإعادة التعيين.',
                style:
                    TextStyle(color: DesignTokens.secondaryText, height: 1.6)),
            const SizedBox(height: DesignTokens.space16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'البريد الإلكتروني مطلوب';
                return isPlausibleEmail(value)
                    ? null
                    : 'أدخل بريدًا إلكترونيًا صحيحًا';
              },
              onFieldSubmitted: (_) => _send(),
            ),
            if (_error != null) ...[
              const SizedBox(height: DesignTokens.space12),
              Text(_error!, style: const TextStyle(color: DesignTokens.error)),
            ],
            const SizedBox(height: DesignTokens.space24),
            SizedBox(
              height: DesignTokens.buttonHeight,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال رابط الاستعادة'),
              ),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('العودة'),
            ),
          ],
        ),
      );
}
