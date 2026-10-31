import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// Mandatory password change screen shown on first login for students and teachers
/// who were provisioned with an initial temporary password by the director.
class ChangePasswordFirstTimeScreen extends ConsumerStatefulWidget {
  const ChangePasswordFirstTimeScreen({super.key});

  @override
  ConsumerState<ChangePasswordFirstTimeScreen> createState() =>
      _ChangePasswordFirstTimeScreenState();
}

class _ChangePasswordFirstTimeScreenState
    extends ConsumerState<ChangePasswordFirstTimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateNew(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'كلمة المرور الجديدة مطلوبة';
    if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _newPassword.text) return 'كلمة المرور غير متطابقة';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // In production, update password on current user
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      final session = ref.read(currentSessionProvider);
      final home = session.homeRoute ?? Routes.login;
      context.go(home);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحديث كلمة المرور: $e');
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
                bottomRadius: 36,
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Rosette(
                        size: 64,
                        color: DesignTokens.gold,
                        child: const Icon(Icons.lock_reset_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تعيين كلمة مرور خاصة لحسابك',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'لأمان حسابك، يُرجى تغيير كلمة المرور المؤقتة قبل المتابعة',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
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
                        TextFormField(
                          controller: _newPassword,
                          obscureText: _obscure1,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الجديدة *',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure1
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            ),
                          ),
                          validator: _validateNew,
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: _obscure2,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة *',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure2
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                            ),
                          ),
                          validator: _validateConfirm,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: DesignTokens.space16),
                          Container(
                            padding: const EdgeInsets.all(DesignTokens.space12),
                            decoration: BoxDecoration(
                              color: DesignTokens.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusMedium),
                              border: Border.all(
                                  color: DesignTokens.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: DesignTokens.error, fontSize: 13),
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
                              : const Text('حفظ والمتابعة إلى حسابي'),
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
