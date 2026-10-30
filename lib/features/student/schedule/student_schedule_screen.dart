import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/features/director/circles/circle_detail_data.dart'
    show circleModeLabel;
import 'package:quran_center/features/student/widgets/student_scaffold.dart';

/// Upcoming sessions of the student's circle.
class StudentScheduleScreen extends StatelessWidget {
  const StudentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'الجدول',
      navIndex: 2,
      builder: (context, ref, d) {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final upcoming =
            d.sessions.where((s) => !s.date.isBefore(start)).toList();

        if (d.circle == null) {
          return ListView(children: const [
            Padding(
              padding: EdgeInsets.all(DesignTokens.space24),
              child: Text('لم تُسجَّل في حلقة بعد. تواصل مع إدارة الدار.',
                  textAlign: TextAlign.center),
            ),
          ]);
        }
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.space16),
          children: [
            Text(d.circle!.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: DesignTokens.space8),
            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.all(DesignTokens.space24),
                child: Text('لا توجد حصص قادمة.', textAlign: TextAlign.center),
              ),
            for (final s in upcoming)
              Card(
                child: ListTile(
                  title: Text(DateFormat.MMMEd('ar').format(s.date),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${s.startTime}–${s.endTime} • ${circleModeLabel(s.locationOrMode)}'),
                  trailing: s.status == SessionStatus.cancelled
                      ? const Text('ملغاة',
                          style: TextStyle(
                              color: DesignTokens.error,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
