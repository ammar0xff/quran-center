import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

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

  AccountMode _accountMode = AccountMode.none; // default: no login
  EnrollmentStatus _enrollmentStatus = EnrollmentStatus.active;
  bool _submitting = false;
  int _section = 0; // 0=A, 1=B, 2=C, 3=D

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _preferredNameController.dispose();
    _educationalLevelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(studentRepositoryProvider);
      final student = Student(
        studentId: 's_${DateTime.now().millisecondsSinceEpoch}',
        centerId: 'center-1',
        fullName: _fullNameController.text.trim(),
        preferredName: _preferredNameController.text.trim().isEmpty
            ? null
            : _preferredNameController.text.trim(),
        accountMode: _accountMode,
        enrollmentStatus: _enrollmentStatus,
        educationalLevel: _educationalLevelController.text.trim().isEmpty
            ? 'مبتدئ'
            : _educationalLevelController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.createStudent(student);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إضافة الطالب بنجاح'),
        backgroundColor: DesignTokens.success,
      ));
      // TODO: navigate to new student profile
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل الإضافة: $e'),
        backgroundColor: DesignTokens.error,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              _sectionHeader('ب. الإعداد التعليمي', 'الحلقة والمعلم وتاريخ التسجيل'),
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
              const SizedBox(height: DesignTokens.space16),
              ListTile(
                title: const Text('تاريخ التسجيل'),
                subtitle: Text(DateFormat.yMMMMd('ar').format(DateTime.now())),
                trailing: const Icon(Icons.calendar_today),
                onTap: () {},
              ),

              // Section C: Digital access
              _sectionHeader('ج. الوصول الرقمي', 'الطلاب بدون دخول هم الخيار الافتراضي'),
              ListTile(
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
                  decoration: const InputDecoration(
                    labelText: 'بريد إلكتروني (مطلوب إذا تم تفعيل الدخول)',
                  ),
                  validator: _validateRequired,
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
                        'نوع الوصول: ${_accountMode == AccountMode.loginEnabled ? "دخول مفعّل" : "بدون دخول"}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _section > 0
                          ? setState(() => _section--)
                          : null,
                      child: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _save,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('حفظ الطالب'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space24),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNav(
          items: const [
            BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard, activeIcon: Icons.dashboard),
            BottomNavItem(label: 'الطلاب', icon: Icons.people, activeIcon: Icons.people),
            BottomNavItem(label: 'الحلقات', icon: Icons.school, activeIcon: Icons.school),
            BottomNavItem(label: 'التقارير', icon: Icons.insert_chart, activeIcon: Icons.insert_chart),
            BottomNavItem(label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu),
          ],
          currentIndex: 1,
          onTap: (i) {},
        ),
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
