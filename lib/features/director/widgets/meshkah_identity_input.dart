import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';

/// Reusable input widget for provisioning student and teacher accounts with
/// the official `<username>@<center_slug>.meshkah` format or traditional email,
/// accompanied by an initial temporary password.
class MeshkahIdentityInput extends ConsumerStatefulWidget {
  const MeshkahIdentityInput({
    super.key,
    required this.onChanged,
    this.initialUsername = '',
    this.initialPassword,
    this.requirePassword = true,
  });

  /// Called whenever the resolved full email or temporary password changes.
  final void Function(String email, String? temporaryPassword) onChanged;
  final String initialUsername;
  final String? initialPassword;
  final bool requirePassword;

  @override
  ConsumerState<MeshkahIdentityInput> createState() =>
      _MeshkahIdentityInputState();
}

class _MeshkahIdentityInputState extends ConsumerState<MeshkahIdentityInput> {
  bool _useMeshkahIdentity = true;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.initialUsername;
    _passwordController.text =
        widget.initialPassword ?? _generateDefaultPassword();
    _usernameController.addListener(_notify);
    _emailController.addListener(_notify);
    _passwordController.addListener(_notify);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateDefaultPassword() {
    final rand = Random().nextInt(9000) + 1000;
    return 'Mshk@$rand';
  }

  void _notify() {
    final centerSlug = ref.read(centerIdProvider);
    final email = _useMeshkahIdentity
        ? '${_usernameController.text.trim().toLowerCase()}@$centerSlug.meshkah'
        : _emailController.text.trim().toLowerCase();
    final pwd = _passwordController.text.trim();
    widget.onChanged(email, pwd.isEmpty ? null : pwd);
  }

  void _copyCredentials(String centerSlug) {
    final email = _useMeshkahIdentity
        ? '${_usernameController.text.trim().toLowerCase()}@$centerSlug.meshkah'
        : _emailController.text.trim();
    final pwd = _passwordController.text.trim();
    final text = 'بيانات الدخول لمنصة مشكاة:\nاسم المستخدم: $email\nكلمة المرور المؤقتة: $pwd';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ بيانات الدخول إلى الحافظة بنجاح 📋'),
        backgroundColor: DesignTokens.primaryDarkGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerSlug = ref.watch(centerIdProvider);
    final resolvedUsername = _usernameController.text.trim().toLowerCase();
    final fullMeshkahId =
        resolvedUsername.isEmpty ? 'اسم_المستخدم@$centerSlug.meshkah' : '$resolvedUsername@$centerSlug.meshkah';

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Selector between Meshkah direct identity vs custom email
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: const Text('معرف مشكاة المباشر'),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: const Text('بريد إلكتروني تقليدي'),
                icon: const Icon(Icons.email_outlined, size: 16),
              ),
            ],
            selected: {_useMeshkahIdentity},
            onSelectionChanged: (newSelection) {
              setState(() {
                _useMeshkahIdentity = newSelection.first;
              });
              _notify();
            },
          ),
          const SizedBox(height: DesignTokens.space16),

          // 2. Identity Input Field
          if (_useMeshkahIdentity) ...[
            TextFormField(
              controller: _usernameController,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم بالإنجليزية *',
                hintText: 'e.g. ahmed-salem',
                prefixIcon: const Icon(Icons.alternate_email_rounded,
                    color: DesignTokens.primaryDarkGreen),
                suffixText: '@$centerSlug.meshkah',
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.primaryDarkGreen,
                ),
              ),
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'اسم المستخدم مطلوب';
                if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(val)) {
                  return 'أحرف إنجليزية وأرقام ونقاط فقط';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: DesignTokens.primaryDarkGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'المعرف النهائي لتسجيل الدخول: $fullMeshkahId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.primaryDarkGreen,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني الشخصي *',
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'البريد الإلكتروني مطلوب';
                if (!isPlausibleEmail(val)) return 'أدخل بريدًا إلكترونيًا صحيحًا';
                return null;
              },
            ),
          ],

          const SizedBox(height: DesignTokens.space16),

          // 3. Temporary Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'كلمة المرور المؤقتة *',
              helperText: 'سيُطلب من المستخدم تغييرها فور أول تسجيل دخول لأمانه',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  IconButton(
                    tooltip: 'توليد كلمة مرور عشوائية',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      _passwordController.text = _generateDefaultPassword();
                    },
                  ),
                ],
              ),
            ),
            validator: (v) {
              if (widget.requirePassword) {
                final val = v ?? '';
                if (val.isEmpty) return 'كلمة المرور المؤقتة مطلوبة';
                if (val.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
              }
              return null;
            },
          ),

          const SizedBox(height: DesignTokens.space12),

          // 4. Quick Action: Copy credentials for sharing with student/guardian
          OutlinedButton.icon(
            onPressed: () => _copyCredentials(centerSlug),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('نسخ بيانات الدخول لمشاركتها مع المستخدم'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
