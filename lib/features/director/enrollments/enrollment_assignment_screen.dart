import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Director enrollment & assignment screen.
///
/// Links a student to a circle and teacher via an Enrollment record, with a
/// start date and status. Preserves enrollment history (no deletion).
class EnrollmentAssignmentScreen extends ConsumerStatefulWidget {
  const EnrollmentAssignmentScreen({super.key});

  @override
  ConsumerState<EnrollmentAssignmentScreen> createState() => _EnrollmentAssignmentScreenState();
}

class _EnrollmentAssignmentScreenState extends ConsumerState<EnrollmentAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String? _selectedCircleId;
  String? _selectedTeacherId;
  DateTime _startDate = DateTime.now();
  EnrollmentStatus _status = EnrollmentStatus.active;
  String? _changeReason;
  bool _submitting = false;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _circles = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    final studentRepo = ref.read(studentRepositoryProvider);
    final circleRepo = ref.read(circleRepositoryProvider);
    final students = await studentRepo.getStudentsByCenter('center-1');
    final circles = await circleRepo.getCirclesByCenter('center-1');
    if (!mounted) return;
    setState(() {
      _students = students.map((s) => {'id': s.studentId, 'name': s.displayName}).toList();
      _circles = circles.map((c) => {'id': c.circleId, 'name': c.name}).toList();
      _loading = false;
    });
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null || _selectedCircleId == null) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(enrollmentRepositoryProvider);
      await repo.createEnrollment(Enrollment(
        enrollmentId: 'e_${DateTime.now().millisecondsSinceEpoch}',
        centerId: 'center-1',
        studentId: _selectedStudentId!,
        circleId: _selectedCircleId!,
        teacherId: _selectedTeacherId,
        startDate: _startDate,
        status: _status,
        changeReason: _changeReason,
        changedBy: 'director',
        changedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تعيين الطالب للحلقة بنجاح'),
        backgroundColor: DesignTokens.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل التعيين: $e'),
        backgroundColor: DesignTokens.error,
      ));
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
        appBar: AppBar(
          title: const Text('تعيين الطالب للحلقة'),
          centerTitle: false,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(DesignTokens.space20),
                  children: [
                    const Text(
                      'اختر الطالب والحلقة والمعلم لإرفاق الطالب بحلقة تعليمية.',
                      style: TextStyle(fontSize: 14, color: DesignTokens.secondaryText),
                    ),
                    const SizedBox(height: DesignTokens.space24),
                    DropdownButtonFormField<String>(
                      value: _selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'الطالب *',
                        hintText: 'اختر طالبًا',
                      ),
                      items: _students
                          .map((s) => DropdownMenuItem<String>(
                                value: s['id'] as String,
                                child: Text(s['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStudentId = v),
                      validator: (v) => v == null ? 'اختر طالبًا' : null,
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    DropdownButtonFormField<String>(
                      value: _selectedCircleId,
                      decoration: const InputDecoration(
                        labelText: 'الحلقة *',
                        hintText: 'اختر حلقة',
                      ),
                      items: _circles
                          .map((c) => DropdownMenuItem<String>(
                                value: c['id'] as String,
                                child: Text(c['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCircleId = v),
                      validator: (v) => v == null ? 'اختر حلقة' : null,
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    DropdownButtonFormField<String>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'المعلم (اختياري)',
                        hintText: 'اختر معلمًا',
                      ),
                      items: _teachers
                          .map((t) => DropdownMenuItem<String>(
                                value: t['id'] as String,
                                child: Text(t['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTeacherId = v),
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    ListTile(
                      title: const Text('تاريخ بدء التسجيل'),
                      subtitle: Text(DateFormat.yMMMMd('ar').format(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    DropdownButtonFormField<EnrollmentStatus>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'حالة التسجيل'),
                      items: EnrollmentStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(_statusLabel(s)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'سبب التغيير (اختياري)',
                        hintText: 'مثال: نقل ثابت',
                      ),
                      onChanged: (v) => _changeReason = v,
                    ),
                    const SizedBox(height: DesignTokens.space32),
                    SizedBox(
                      width: double.infinity,
                      height: DesignTokens.buttonHeight,
                      child: FilledButton(
                        onPressed: _submitting ? null : _assign,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('تعيين'),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space24),
                  ],
                ),
              ),
        bottomNavigationBar: CustomBottomNav(
          items: const [
            BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard, activeIcon: Icons.dashboard),
            BottomNavItem(label: 'الطلاب', icon: Icons.people, activeIcon: Icons.people),
            BottomNavItem(label: 'المعلمون', icon: Icons.person, activeIcon: Icons.person),
            BottomNavItem(label: 'الحلقات', icon: Icons.school, activeIcon: Icons.school),
            BottomNavItem(label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu),
          ],
          currentIndex: 3,
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
