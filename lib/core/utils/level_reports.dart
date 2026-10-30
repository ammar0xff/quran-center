import 'package:quran_center/core/utils/report_builders.dart';
import 'package:quran_center/core/utils/wird_level.dart';
import 'package:quran_center/data/models/enums.dart';

class StudentLevelRow {
  const StudentLevelRow({
    required this.studentId,
    required this.name,
    required this.circleName,
    required this.teacherNames,
    required this.level,
  });
  final String studentId;
  final String name;
  final String circleName;
  final List<String> teacherNames;
  final WirdLevel level;
}

/// The level of every active student, from ALL the wirds heard for them
/// (whichever teacher heard them). Students with no graded wird come last and
/// show no level. Within the rest: weakest first, so the director sees who
/// needs attention at the top.
List<StudentLevelRow> studentLevels(ReportData d) {
  final circle = {for (final c in d.circles) c.circleId: c.name};
  final teacher = {for (final t in d.teachers) t.teacherId: t.fullName};
  final byStudent = <String, List<dynamic>>{};
  for (final a in d.assessments) {
    (byStudent[a.studentId] ??= []).add(a);
  }
  final rows = [
    for (final s in d.students)
      if (s.enrollmentStatus == EnrollmentStatus.active)
        StudentLevelRow(
          studentId: s.studentId,
          name: s.displayName,
          circleName: circle[s.currentCircleId] ?? '',
          teacherNames: [
            for (final id in s.assignedTeacherIds)
              if (teacher[id] != null) teacher[id]!
          ],
          level: computeLevel(
              [for (final a in byStudent[s.studentId] ?? const []) a]),
        ),
  ];
  rows.sort((a, b) {
    final x = a.level.average, y = b.level.average;
    if (x == null && y == null) return a.name.compareTo(b.name);
    if (x == null) return 1;
    if (y == null) return -1;
    final c = x.compareTo(y);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return rows;
}

class TeacherLevelRow {
  const TeacherLevelRow({
    required this.teacherId,
    required this.name,
    required this.students,
    required this.studentsWithLevel,
    required this.studentsAverage,
    required this.wirdsHeard,
    required this.gradeGiven,
  });
  final String teacherId;
  final String name;

  /// Active students currently assigned to this teacher.
  final int students;
  final int studentsWithLevel;

  /// Mean of those students' levels (1-5); null if none has a level yet.
  final double? studentsAverage;

  /// Graded wirds this teacher heard (including visiting students).
  final int wirdsHeard;

  /// The mean mark this teacher gave (1-5). It describes grading habits, not
  /// teaching quality: it is shown next to the students' own level.
  final double? gradeGiven;
}

List<TeacherLevelRow> teacherLevels(ReportData d) {
  final levels = {for (final r in studentLevels(d)) r.studentId: r.level};
  final rows = <TeacherLevelRow>[];
  for (final t in d.teachers) {
    final mine = d.students.where((s) =>
        s.enrollmentStatus == EnrollmentStatus.active &&
        s.assignedTeacherIds.contains(t.teacherId));
    final avgs = [
      for (final s in mine)
        if (levels[s.studentId]?.average != null) levels[s.studentId]!.average!
    ];
    final heard = d.assessments
        .where((a) =>
            a.teacherId == t.teacherId &&
            a.grade != null &&
            gradedTypes.contains(a.assessmentType))
        .toList();
    rows.add(TeacherLevelRow(
      teacherId: t.teacherId,
      name: t.fullName,
      students: mine.length,
      studentsWithLevel: avgs.length,
      studentsAverage:
          avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length,
      wirdsHeard: heard.length,
      gradeGiven: heard.isEmpty
          ? null
          : heard.map((a) => a.grade!.score).reduce((a, b) => a + b) /
              heard.length,
    ));
  }
  rows.sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

/// 4.2 -> "4.2 (جيد جدًا)"; null -> "—".
String averageText(double? a) {
  if (a == null) return '—';
  final label = WirdLevel(
    total: 1,
    counts: const {},
    average: a,
    byType: const {},
    trend: Trend.unknown,
    lastHeard: null,
  ).label;
  return '${a.toStringAsFixed(1)} ($label)';
}
