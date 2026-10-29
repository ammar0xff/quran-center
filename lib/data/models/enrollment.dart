import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// Enrollment links a student to a circle/teacher over a time period.
///
/// A student may have multiple enrollment records over time (transfers,
/// re-enrollment). History is preserved; archival never deletes records.
class Enrollment extends AppModel {
  const Enrollment({
    required this.enrollmentId,
    required this.centerId,
    required this.studentId,
    required this.circleId,
    this.teacherId,
    required this.startDate,
    this.endDate,
    required this.status,
    this.changeReason,
    this.changedBy,
    this.changedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String enrollmentId;
  final String centerId;
  final String studentId;
  final String circleId;
  final String? teacherId;
  final DateTime startDate;
  final DateTime? endDate;
  final EnrollmentStatus status;
  final String? changeReason;
  final String? changedBy;
  final DateTime? changedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == EnrollmentStatus.active;

  Enrollment copyWith({
    DateTime? endDate,
    EnrollmentStatus? status,
    String? changeReason,
    String? changedBy,
    DateTime? changedAt,
    DateTime? updatedAt,
  }) {
    return Enrollment(
      enrollmentId: enrollmentId,
      centerId: centerId,
      studentId: studentId,
      circleId: circleId,
      teacherId: teacherId,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      changeReason: changeReason ?? this.changeReason,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Enrollment.fromJson(String enrollmentId, JsonMap json) {
    return Enrollment(
      enrollmentId: enrollmentId,
      centerId: json['centerId'] as String,
      studentId: json['studentId'] as String,
      circleId: json['circleId'] as String,
      teacherId: json['teacherId'] as String?,
      startDate: AppModel.parseDateTime(json['startDate']) ?? DateTime.now(),
      endDate: AppModel.parseDateTime(json['endDate']),
      status: EnrollmentStatusJson.fromJson(json['status'] as String?),
      changeReason: json['changeReason'] as String?,
      changedBy: json['changedBy'] as String?,
      changedAt: AppModel.parseDateTime(json['changedAt']),
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'studentId': studentId,
      'circleId': circleId,
      if (teacherId != null) 'teacherId': teacherId,
      'startDate': AppModel.encodeDateTime(startDate),
      if (endDate != null) 'endDate': AppModel.encodeDateTime(endDate),
      'status': status.toJson(),
      if (changeReason != null) 'changeReason': changeReason,
      if (changedBy != null) 'changedBy': changedBy,
      if (changedAt != null) 'changedAt': AppModel.encodeDateTime(changedAt),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Enrollment &&
          runtimeType == other.runtimeType &&
          enrollmentId == other.enrollmentId;

  @override
  int get hashCode => enrollmentId.hashCode;

  @override
  String toString() =>
      'Enrollment(enrollmentId: $enrollmentId, studentId: $studentId, circleId: $circleId, status: $status)';
}
