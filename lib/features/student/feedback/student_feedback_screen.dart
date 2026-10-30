import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/features/student/widgets/student_scaffold.dart';
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart'
    show assessmentTypeLabel;

/// Notes from the teacher. Only what the teacher wrote for the student is
/// shown: no scores, no mistake counts, and never the private note.
class StudentFeedbackScreen extends StatelessWidget {
  const StudentFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'الملاحظات',
      navIndex: 3,
      builder: (context, ref, d) {
        final items = d.feedback
            .where((r) =>
                r.studentVisibleFeedback != null ||
                r.strengths != null ||
                r.areasForImprovement != null ||
                r.recommendedNextAssignment != null)
            .toList();
        if (items.isEmpty) {
          return ListView(children: const [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space24),
              child: Text('لا توجد ملاحظات من المعلم بعد.', textAlign: TextAlign.center),
            ),
          ]);
        }
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space16),
          children: [
            for (final r in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${assessmentTypeLabel(r.assessmentType)} • '
                        '${surahByNumber(r.surah)?.name ?? ''}: ${r.startAyah}–${r.endAyah}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(DateFormat.yMMMd('ar').format(r.assessedAt),
                          style: const TextStyle(color: DesignTokens.secondaryText)),
                      const SizedBox(height: DesignTokens.space8),
                      if (r.studentVisibleFeedback != null) Text(r.studentVisibleFeedback!),
                      if (r.strengths != null) Text('نقاط القوة: ${r.strengths}'),
                      if (r.areasForImprovement != null)
                        Text('للتحسين: ${r.areasForImprovement}'),
                      if (r.recommendedNextAssignment != null)
                        Text('الواجب المقترح: ${r.recommendedNextAssignment}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
