import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// Metadata for an attendance correction (audit trail).
class AttendanceCorrection {
  const AttendanceCorrection({
    required this.originalStatus,
    required this.correctedBy,
    required this.correctedAt,
    required this.reason,
  });

  final AttendanceStatus originalStatus;
  final String correctedBy;
  final DateTime correctedAt;
  final String reason;

  factory AttendanceCorrection.fromJson(JsonMap json) {
    return AttendanceCorrection(
      originalStatus: AttendanceStatusJson.fromJson(json['originalStatus'] as String?),
      correctedBy: json['correctedBy'] as String,
      correctedAt: AppModel.parseDateTime(json['correctedAt']) ?? DateTime.now(),
      reason: json['reason'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'originalStatus': originalStatus.toJson(),
      'correctedBy': correctedBy,
      'correctedAt': AppModel.encodeDateTime(correctedAt),
      'reason': reason,
    };
  }
}

/// One attendance record per student per session.
class Attendance extends AppModel {
  const Attendance({
    required this.attendanceId,
    required this.centerId,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.recordedBy,
    this.note,
    this.correctionMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String attendanceId;
  final String centerId;
  final String sessionId;
  final String studentId;
  final AttendanceStatus status;
  final String recordedBy; // teacherId
  final String? note;
  final AttendanceCorrection? correctionMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Attendance copyWith({
    AttendanceStatus? status,
    String? note,
    AttendanceCorrection? correctionMetadata,
    DateTime? updatedAt,
  }) {
    return Attendance(
      attendanceId: attendanceId,
      centerId: centerId,
      sessionId: sessionId,
      studentId: studentId,
      status: status ?? this.status,
      recordedBy: recordedBy,
      note: note ?? this.note,
      correctionMetadata: correctionMetadata ?? this.correctionMetadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Attendance.fromJson(String attendanceId, JsonMap json) {
    return Attendance(
      attendanceId: attendanceId,
      centerId: json['centerId'] as String,
      sessionId: json['sessionId'] as String,
      studentId: json['studentId'] as String,
      status: AttendanceStatusJson.fromJson(json['status'] as String?),
      recordedBy: json['recordedBy'] as String,
      note: json['note'] as String?,
      correctionMetadata: json['correctionMetadata'] != null
          ? AttendanceCorrection.fromJson(json['correctionMetadata'] as JsonMap)
          : null,
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'sessionId': sessionId,
      'studentId': studentId,
      'status': status.toJson(),
      'recordedBy': recordedBy,
      if (note != null) 'note': note,
      if (correctionMetadata != null)
        'correctionMetadata': correctionMetadata!.toJson(),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attendance && runtimeType == other.runtimeType && attendanceId == other.attendanceId;

  @override
  int get hashCode => attendanceId.hashCode;

  @override
  String toString() =>
      'Attendance(attendanceId: $attendanceId, studentId: $studentId, status: $status)';
}
