import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';

/// Deterministic attendance document id: one record per student per session.
///
/// Using this as the Firestore document id makes duplicates impossible and
/// makes retries idempotent.
String attendanceDocId(String sessionId, String studentId) =>
    '${sessionId}_$studentId';

/// Aggregated attendance counts.
///
/// Definitions (documented policy, shown in the UI):
/// * [missing] = expected records that were never recorded. A missing record
///   is NOT treated as an absence.
/// * [rate] = (present + late) / (present + late + absent).
///   Excused records and missing records are excluded from the denominator.
///   Returns null when the denominator is zero (no basis for a rate).
class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.missing,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;
  final int missing;

  int get recorded => present + absent + late + excused;

  double? get rate {
    final denominator = present + late + absent;
    if (denominator == 0) return null;
    return (present + late) / denominator;
  }

  /// Builds a summary from [records]. [expectedCount] is the number of
  /// student/session pairs that should have a record; missing is clamped to
  /// zero if more records exist than expected.
  factory AttendanceSummary.from(
    Iterable<Attendance> records, {
    int? expectedCount,
  }) {
    var present = 0, absent = 0, late = 0, excused = 0;
    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.excused:
          excused++;
      }
    }
    final recorded = present + absent + late + excused;
    final missing = expectedCount == null
        ? 0
        : (expectedCount - recorded).clamp(0, 1 << 30);
    return AttendanceSummary(
      present: present,
      absent: absent,
      late: late,
      excused: excused,
      missing: missing,
    );
  }
}

/// Why a correction request was rejected.
enum CorrectionError { reasonRequired, sameStatus }

/// Validates a correction request. Returns null when valid.
CorrectionError? validateCorrection({
  required AttendanceStatus current,
  required AttendanceStatus requested,
  required String reason,
}) {
  if (reason.trim().isEmpty) return CorrectionError.reasonRequired;
  if (current == requested) return CorrectionError.sameStatus;
  return null;
}
