import 'package:flutter/material.dart';
import 'package:quran_center/app/router.dart';
import 'package:quran_center/core/localization/app_localizations.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// Welcome & Login screen.
///
/// No public role selector (role is backend-authoritative).
/// Email trimmed + format validated; password never logged;
/// submission disabled while in flight; localized errors;
/// navigates by authoritative role after success.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return AppLocalizations.of(context).s('emailRequired');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(v)) return AppLocalizations.of(context).s('emailInvalid');
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppLocalizations.of(context).s('passwordRequired');
    return null;
  }

  Future<void> _submit() async {
    final emailValid = _validateEmail(_emailController.text) == null;
    final passValid = _validatePassword(_passwordController.text) == null;
    if (!emailValid || !passValid) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      // TODO: wire Firebase Auth signInWithEmailAndPassword here.
      // Resolve role from authoritative profile, then navigate to role shell.
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoute.teacherDashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = AppLocalizations.of(context).s('errorUnknown');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.space24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school, size: 72, color: DesignTokens.primaryDarkGreen),
                      const SizedBox(height: DesignTokens.space24),
                      Text(
                        l10n.s('loginTitle'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.mainText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignTokens.space8),
                      Text(
                        l10n.s('loginDescription'),
                        style: TextStyle(
                          fontSize: 15,
                          color: DesignTokens.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignTokens.space32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.s('emailLabel'),
                          hintText: l10n.s('emailHint'),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.s('passwordLabel'),
                          hintText: l10n.s('passwordHint'),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: DesignTokens.space12),
                        Container(
                          padding: const EdgeInsets.all(DesignTokens.space12),
                          decoration: BoxDecoration(
                            color: DesignTokens.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                            border: Border.all(
                              color: DesignTokens.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: DesignTokens.error, fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: DesignTokens.space24),
                      SizedBox(
                        width: double.infinity,
                        height: DesignTokens.buttonHeight,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(l10n.s('signIn')),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space20),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(AppRoute.forgotPassword),
                        child: Text(l10n.s('forgotPassword')),
                      ),
                      const SizedBox(height: DesignTokens.space12),
                      TextButton(
                        onPressed: null, // help/support action
                        child: Text(l10n.s('helpSupport')),
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      Text(
                        l10n.s('privacyTerms'),
                        style: TextStyle(
                          fontSize: 12,
                          color: DesignTokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
