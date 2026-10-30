import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/design_system/components/rosette.dart';
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
        final items =
            d.feedback; // every wird heard for this student, newest first
        if (items.isEmpty) {
          return ListView(children: const [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space24),
              child:
                  Text('لم يُسجَّل لك تسميع بعد.', textAlign: TextAlign.center),
            ),
          ]);
        }
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space16),
          children: [
            for (final r in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Rosette(
                          size: 50,
                          color: DesignTokens.gold,
                          child: Text('${r.surah}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(surahByNumber(r.surah)?.name ?? '',
                                  style: const TextStyle(
                                      fontFamily: DesignTokens.nameFont,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A6420),
                                      height: 1.3)),
                              Text(
                                '${assessmentTypeLabel(r.assessmentType)} • الآيات ${r.startAyah}–${r.endAyah}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: DesignTokens.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        if (r.grade != null) GradeChip(r.grade!),
                      ]),
                      const SizedBox(height: 8),
                      Text(DateFormat.yMMMd('ar').format(r.assessedAt),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: DesignTokens.secondaryText)),
                      if (r.studentVisibleFeedback != null ||
                          r.strengths != null ||
                          r.areasForImprovement != null ||
                          r.recommendedNextAssignment != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: DesignTokens.warmOffWhite,
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.studentVisibleFeedback != null)
                                Text(r.studentVisibleFeedback!),
                              if (r.strengths != null)
                                Text('نقاط القوة: ${r.strengths}'),
                              if (r.areasForImprovement != null)
                                Text('للتحسين: ${r.areasForImprovement}'),
                              if (r.recommendedNextAssignment != null)
                                Text(
                                    'الواجب المقترح: ${r.recommendedNextAssignment}'),
                            ],
                          ),
                        ),
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
