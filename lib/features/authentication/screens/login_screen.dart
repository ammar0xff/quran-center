import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// Email + password sign-in.
///
/// There is deliberately no role selector: the role comes from the stored
/// profile after authentication. On success this screen does not navigate;
/// the router moves the user to the right area once the session resolves.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'البريد الإلكتروني مطلوب';
    if (!isPlausibleEmail(value)) return 'أدخل بريدًا إلكترونيًا صحيحًا';
    return null;
  }

  String? _validatePassword(String? v) =>
      (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null;

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authGatewayProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SingleChildScrollView(
          child: Column(
            children: [
              AppHero(
                bottomRadius: 40,
                child: SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Rosette(
                        size: 84,
                        color: DesignTokens.gold,
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 18),
                      const Text('بسم الله الرحمن الرحيم',
                          style: TextStyle(
                              fontFamily: DesignTokens.nameFont,
                              fontSize: 26,
                              color: Color(0xFFE9CF93),
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text('دار تحفيظ القرآن',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تسجيل الدخول',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: DesignTokens.mainText)),
                        const SizedBox(height: 4),
                        const Text('سجّل الدخول إلى حسابك في دار تحفيظ القرآن.',
                            style: TextStyle(
                                fontSize: 14,
                                color: DesignTokens.secondaryText)),
                        const SizedBox(height: DesignTokens.space24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني'),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'إظهار كلمة المرور'
                                  : 'إخفاء كلمة المرور',
                              icon: Icon(_obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: DesignTokens.space12),
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(DesignTokens.space12),
                              decoration: BoxDecoration(
                                color:
                                    DesignTokens.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMedium),
                                border: Border.all(
                                    color: DesignTokens.error
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: DesignTokens.error, fontSize: 13)),
                            ),
                          ),
                        ],
                        const SizedBox(height: DesignTokens.space24),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('تسجيل الدخول'),
                        ),
                        const SizedBox(height: DesignTokens.space8),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => context.push(Routes.forgotPassword),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
