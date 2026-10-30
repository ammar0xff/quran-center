import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

/// Edits a student's descriptive fields (name, level, notes). Enrolment
/// status, login access and center are changed only through their own
/// audited flows. Each save is recorded with the previous and new values.
class EditStudentScreen extends ConsumerStatefulWidget {
  const EditStudentScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _preferred = TextEditingController();
  final _level = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  bool _noteLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _preferred, _level, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    Student? s;
    try {
      s = await ref.read(studentRepositoryProvider).getStudent(widget.studentId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات الطالب';
        _missing = true;
      });
      return;
    }
    if (!mounted) return;
    if (s == null || s.centerId != ref.read(centerIdProvider)) {
      setState(() {
        _loading = false;
        _missing = true;
      });
      return;
    }
    _name.text = s.fullName;
    _preferred.text = s.preferredName ?? '';
    _level.text = s.educationalLevel;
    try {
      _notes.text = await ref
              .read(studentRepositoryProvider)
              .getAdminNote(widget.studentId, centerId: s.centerId) ??
          '';
      _noteLoaded = true;
    } catch (_) {
      // The note is optional; the rest of the form stays usable.
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actor = ref.read(actorProvider);
      final changed = await ref.read(studentRepositoryProvider).updateProfile(
            widget.studentId,
            actorId: actor.id,
            actorRole: actor.role,
            fullName: _name.text,
            preferredName: _preferred.text,
            educationalLevel: _level.text,
            // If the note could not be loaded, leave it untouched.
            adminNotes: _noteLoaded ? _notes.text : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(changed ? 'تم حفظ التعديلات' : 'لا توجد تعديلات لحفظها'),
        backgroundColor: changed ? DesignTokens.success : DesignTokens.secondaryText,
      ));
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ التعديلات. حاول مرة أخرى.';
        });
      }
    }
  }

  String? _required(String? v, String message) =>
      (v ?? '').trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(title: const Text('تعديل بيانات الطالب'), centerTitle: false),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _missing
                ? Center(child: Text(_error ?? 'الطالب غير موجود'))
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(DesignTokens.space20),
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                          validator: (v) => _required(v, 'الاسم مطلوب'),
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        TextFormField(
                          controller: _preferred,
                          decoration:
                              const InputDecoration(labelText: 'الاسم المفضل (اختياري)'),
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        TextFormField(
                          controller: _level,
                          decoration: const InputDecoration(labelText: 'المستوى التعليمي *'),
                          validator: (v) => _required(v, 'المستوى مطلوب'),
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          enabled: _noteLoaded,
                          decoration: const InputDecoration(
                              labelText: 'ملاحظات إدارية (للإدارة فقط)'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: DesignTokens.space16),
                          Text(_error!,
                              style: const TextStyle(color: DesignTokens.error)),
                        ],
                        const SizedBox(height: DesignTokens.space24),
                        SizedBox(
                          height: DesignTokens.buttonHeight,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('حفظ'),
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 1),
      ),
    );
  }
}
