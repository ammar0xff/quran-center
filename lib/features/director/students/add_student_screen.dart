import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/account_access_rules.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Director "Add Student" form.
///
/// Multi-section form:
///   A. Basic information (full name required; DOB/contact optional)
///   B. Educational setup (level, circle, teacher, enrollment date, status)
///   C. Digital access (no login [default] or create login)
///   D. Review summary
///
/// Never forces children/non-technical adults to provide email.
/// Account mode 'none' is the recommended default.
class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _preferredNameController = TextEditingController();
  final _educationalLevelController = TextEditingController();

  final _emailController = TextEditingController();

  /// What the director *wants*. The profile is always created accountless;
  /// a login is requested from the backend afterwards (see [_save]).
  AccountMode _accountMode = AccountMode.none; // default: no login
  EnrollmentStatus _enrollmentStatus = EnrollmentStatus.active;
  bool _submitting = false;
  bool _saved = false;

  /// Fixed for the lifetime of this form so that retrying a failed save
  /// rewrites the same document instead of creating a duplicate profile.
  String _studentId = _newStudentId();

  static String _newStudentId() => 's_${DateTime.now().microsecondsSinceEpoch}';

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
    return isPlausibleEmail(value) ? null : 'أدخل بريدًا إلكترونيًا صحيحًا';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _preferredNameController.dispose();
    _educationalLevelController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? DesignTokens.error : DesignTokens.success,
    ));
  }

  void _addAnother() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _preferredNameController.clear();
    _educationalLevelController.clear();
    _emailController.clear();
    setState(() {
      _accountMode = AccountMode.none;
      _enrollmentStatus = EnrollmentStatus.active;
      _saved = false;
      _studentId = _newStudentId();
    });
  }

  Future<void> _save() async {
    if (_saved || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Step 1: the educational profile. Never blocked by login problems.
    try {
      final now = DateTime.now();
      final actor = ref.read(actorProvider);
      await ref.read(studentRepositoryProvider).createStudent(
          actorId: actor.id,
          actorRole: actor.role,
          Student(
            studentId: _studentId,
            centerId: ref.read(centerIdProvider),
            fullName: _fullNameController.text.trim(),
            preferredName: _preferredNameController.text.trim().isEmpty
                ? null
                : _preferredNameController.text.trim(),
            // Always accountless: only the backend may attach a login.
            accountMode: AccountMode.none,
            enrollmentStatus: _enrollmentStatus,
            educationalLevel: _educationalLevelController.text.trim().isEmpty
                ? 'مبتدئ'
                : _educationalLevelController.text.trim(),
            createdAt: now,
            updatedAt: now,
          ));
    } catch (_) {
      _snack('تعذر حفظ الطالب. البيانات محفوظة في النموذج، حاول مرة أخرى.',
          error: true);
      if (mounted) setState(() => _submitting = false);
      return;
    }

    // Step 2 (optional): request a login for the new profile.
    String? loginProblem;
    if (_accountMode == AccountMode.loginEnabled) {
      try {
        await ref.read(accountAccessServiceProvider).enableStudentAccess(
              studentId: _studentId,
              email: _emailController.text,
            );
      } on AccountAccessException catch (e) {
        loginProblem = e.message;
      }
    }

    if (!mounted) return;
    setState(() {
      _saved = true;
      _submitting = false;
    });
    if (loginProblem == null) {
      _snack(_accountMode == AccountMode.loginEnabled
          ? 'تم إضافة الطالب وتفعيل دخوله'
          : 'تم إضافة الطالب بنجاح');
    } else {
      _snack(
          'تم إنشاء ملف الطالب، لكن لم يُفعَّل الدخول: $loginProblem '
          'يمكنك المحاولة من تبويب الدخول في ملفه.',
          error: true);
    }
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: DesignTokens.space24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
          ),
          const SizedBox(height: DesignTokens.space16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إضافة طالب جديد'),
          centerTitle: false,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(DesignTokens.space20),
            children: [
              // Section A: Basic information
              _sectionHeader('أ. المعلومات الأساسية', 'الاسم الكامل مطلوب؛باقي الحقول اختيارية'),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  hintText: 'أدخل الاسم الكامل للطالب',
                ),
                validator: _validateRequired,
              ),
              const SizedBox(height: DesignTokens.space16),
              TextFormField(
                controller: _preferredNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم المفضل (اختياري)',
                  hintText: 'اسم يُنادي به الطالب',
                ),
              ),
              const SizedBox(height: DesignTokens.space16),
              TextFormField(
                controller: _educationalLevelController,
                decoration: const InputDecoration(
                  labelText: 'المستوى التعليمي',
                  hintText: 'مثال: مبتدئ',
                ),
              ),
              const SizedBox(height: DesignTokens.space24),

              // Section B: Educational setup
              _sectionHeader('ب. الإعداد التعليمي', 'حالة التسجيل'),
              DropdownButtonFormField<EnrollmentStatus>(
                value: _enrollmentStatus,
                decoration: const InputDecoration(labelText: 'حالة التسجيل'),
                items: EnrollmentStatus.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(_statusLabel(s)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _enrollmentStatus = v!),
              ),
              const SizedBox(height: DesignTokens.space8),
              const Text(
                'يُعيَّن الطالب إلى حلقة ومعلم من شاشة «تعيين الطالب للحلقة» بعد الحفظ.',
                style: TextStyle(fontSize: 12, color: DesignTokens.secondaryText),
              ),

              // Section C: Digital access
              _sectionHeader('ج. الوصول الرقمي', 'الطلاب بدون دخول هم الخيار الافتراضي'),
              ListTile(
                onTap: () => setState(() => _accountMode = AccountMode.none),
                leading: Radio<AccountMode>(
                  value: AccountMode.none,
                  groupValue: _accountMode,
                  onChanged: (v) => setState(() => _accountMode = v!),
                ),
                title: const Text('بدون دخول للطالب'),
                subtitle: const Text(
                  'الخيار الافتراضي للأطفال وكبار السن وغير الراغبين في التكنولوجيا',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                onTap: () => setState(() => _accountMode = AccountMode.loginEnabled),
                leading: Radio<AccountMode>(
                  value: AccountMode.loginEnabled,
                  groupValue: _accountMode,
                  onChanged: (v) => setState(() => _accountMode = v!),
                ),
                title: const Text('إنشاء دخول للطالب'),
                subtitle: const Text(
                  'سيتم تزويد الطالب بحساب دخول آمن مرتبط بملفه التعليمي الحالي',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (_accountMode == AccountMode.loginEnabled) ...[
                const SizedBox(height: DesignTokens.space16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'بريد إلكتروني (مطلوب إذا تم تفعيل الدخول)',
                    helperText: 'سيُرسل إليه رابط لتعيين كلمة المرور بعد الحفظ',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: DesignTokens.space16),
              ],

              // Section D: Review
              _sectionHeader('د. المراجعة', 'مراجعة البيانات قبل الحفظ'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاسم: ${_fullNameController.text}'),
                      const SizedBox(height: DesignTokens.space8),
                      Text('المستوى: ${_educationalLevelController.text}'),
                      const SizedBox(height: DesignTokens.space8),
                      Text('حالة التسجيل: ${_statusLabel(_enrollmentStatus)}'),
                      const SizedBox(height: DesignTokens.space8),
                      Text(
                        'نوع الوصول: ${_accountMode == AccountMode.loginEnabled ? "سيُطلب تفعيل الدخول بعد الحفظ" : "بدون دخول"}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space32),

              // Actions
              Row(
                children: [
                  if (_saved) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _addAnother,
                        child: const Text('إضافة طالب آخر'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space16),
                  ],
                  Expanded(
                    child: FilledButton(
                      // Disabled while saving and after a successful save so
                      // the same student cannot be submitted twice.
                      onPressed: (_submitting || _saved) ? null : _save,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(_saved ? 'تم الحفظ' : 'حفظ الطالب'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space24),
            ],
          ),
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }

  String _statusLabel(EnrollmentStatus s) {
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
}
