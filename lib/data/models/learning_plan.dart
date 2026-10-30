import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A learning plan for a student, owned by a responsible teacher.
class LearningPlan extends AppModel {
  const LearningPlan({
    required this.planId,
    required this.centerId,
    required this.studentId,
    required this.responsibleTeacherId,
    this.circleId,
    required this.educationalObjective,
    required this.startDate,
    required this.targetDate,
    required this.status,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String planId;
  final String centerId;
  final String studentId;
  final String responsibleTeacherId;
  final String? circleId;
  final String educationalObjective;
  final DateTime startDate;
  final DateTime targetDate;
  final PlanStatus status;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == PlanStatus.active;

  LearningPlan copyWith({
    String? educationalObjective,
    DateTime? startDate,
    DateTime? targetDate,
    PlanStatus? status,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return LearningPlan(
      planId: planId,
      centerId: centerId,
      studentId: studentId,
      responsibleTeacherId: responsibleTeacherId,
      circleId: circleId,
      educationalObjective: educationalObjective ?? this.educationalObjective,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory LearningPlan.fromJson(String planId, JsonMap json) {
    return LearningPlan(
      planId: planId,
      centerId: json['centerId'] as String,
      studentId: json['studentId'] as String,
      responsibleTeacherId: json['responsibleTeacherId'] as String,
      circleId: json['circleId'] as String?,
      educationalObjective: json['educationalObjective'] as String,
      startDate: AppModel.parseDateTime(json['startDate']) ?? DateTime.now(),
      targetDate: AppModel.parseDateTime(json['targetDate']) ?? DateTime.now(),
      status: PlanStatusJson.fromJson(json['status'] as String?),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'studentId': studentId,
      'responsibleTeacherId': responsibleTeacherId,
      if (circleId != null) 'circleId': circleId,
      'educationalObjective': educationalObjective,
      'startDate': AppModel.encodeDateTime(startDate),
      'targetDate': AppModel.encodeDateTime(targetDate),
      'status': status.toJson(),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningPlan &&
          runtimeType == other.runtimeType &&
          planId == other.planId;

  @override
  int get hashCode => planId.hashCode;

  @override
  String toString() =>
      'LearningPlan(planId: $planId, studentId: $studentId, status: $status)';
}
