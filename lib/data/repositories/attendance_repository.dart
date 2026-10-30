import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';

/// Thrown when recording attendance that already exists with different data.
/// Changes to an existing record must go through [AttendanceRepository.correct].
class DuplicateAttendanceException implements Exception {
  DuplicateAttendanceException(this.attendanceId);
  final String attendanceId;
  @override
  String toString() => 'Attendance already recorded: $attendanceId';
}

/// Thrown when a correction request is invalid or the record is missing.
class AttendanceCorrectionException implements Exception {
  AttendanceCorrectionException(this.message, {this.error});
  final String message;
  final CorrectionError? error;
  @override
  String toString() => message;
}

abstract class AttendanceRepository {
  /// Records attendance using the deterministic id
  /// ([attendanceDocId]). Re-recording identical data is a no-op (idempotent
  /// retries); different data throws [DuplicateAttendanceException].
  Future<void> record(Attendance attendance);

  Future<List<Attendance>> getBySession(String sessionId);

  Future<List<Attendance>> getByStudent(String studentId,
      {required String centerId});

  Future<List<Attendance>> getByCenter(String centerId);

  /// Corrects an existing record. Requires a reason, preserves the original
  /// status, and writes an audit entry atomically with the change.
  Future<void> correct({
    required String sessionId,
    required String studentId,
    required AttendanceStatus newStatus,
    required String actorId,
    required String actorRole,
    required String reason,
  });
}
