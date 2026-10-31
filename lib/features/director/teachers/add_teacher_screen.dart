import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/widgets/meshkah_identity_input.dart';

/// Director form that creates a teacher account.
///
/// The login, role, profile and teacher record are created together by the
/// backend (the client never creates accounts). Activation instructions are
/// emailed to the teacher so they set their own password.
class AddTeacherScreen extends ConsumerStatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  ConsumerState<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends ConsumerState<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String? _temporaryPassword;
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'الاسم مطلوب';
    return value.length < 2 ? 'الاسم قصير جدًا' : null;
  }

  void _finish(String message, {bool warning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: warning ? DesignTokens.warning : DesignTokens.success,
    ));
    context.go('/director/teachers');
  }

  Future<void> _submit() async {
    if (_submitting || _done || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(accountAccessServiceProvider).createTeacher(
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            professionalNotes: _notes.text,
            temporaryPassword: _temporaryPassword,
          );
      if (!mounted) return;
      setState(() => _done = true);
      _finish('تم إنشاء حساب المعلم وإرسال رسالة التفعيل');
    } on ActivationEmailException catch (e) {
      // The account exists; only the email failed. Do not invite a retry that
      // would be rejected as "email already in use".
      if (!mounted) return;
      setState(() => _done = true);
      _finish(e.message, warning: true);
    } on AccountAccessException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted && !_done) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('إضافة معلم'), centerTitle: false),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(DesignTokens.space20),
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                validator: _validateName,
              ),
              const SizedBox(height: DesignTokens.space16),
              MeshkahIdentityInput(
                onChanged: (email, tempPassword) {
                  _email.text = email;
                  _temporaryPassword = tempPassword;
                },
              ),
              const SizedBox(height: DesignTokens.space16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'الجوال (اختياري)'),
              ),
              const SizedBox(height: DesignTokens.space16),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات مهنية (اختياري)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.space16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.space12),
                    decoration: BoxDecoration(
                      color: DesignTokens.error.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSmall),
                      border: Border.all(
                          color: DesignTokens.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: DesignTokens.error)),
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.space24),
              SizedBox(
                height: DesignTokens.buttonHeight,
                child: FilledButton(
                  onPressed: (_submitting || _done) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('إنشاء حساب المعلم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
