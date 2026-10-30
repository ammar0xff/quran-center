import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A weekly schedule entry for a circle.
class CircleWeeklySchedule {
  const CircleWeeklySchedule({
    required this.dayOfWeek, // 0=Sunday ... 6=Saturday (ISO-ish; 1=Monday in Islamic contexts)
    required this.startTime, // HH:mm
    required this.endTime, // HH:mm
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;

  CircleWeeklySchedule copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
  }) {
    return CircleWeeklySchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  factory CircleWeeklySchedule.fromJson(JsonMap json) {
    return CircleWeeklySchedule(
      dayOfWeek: json['dayOfWeek'] as int,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  JsonMap toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleWeeklySchedule &&
          runtimeType == other.runtimeType &&
          dayOfWeek == other.dayOfWeek &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(dayOfWeek, startTime, endTime);
}

/// A teaching circle (class group).
class Circle extends AppModel {
  const Circle({
    required this.circleId,
    required this.centerId,
    required this.name,
    this.description,
    required this.educationalLevel,
    this.assignedTeacherId,
    required this.maxCapacity,
    this.activeCount = 0,
    required this.locationOrMode,
    required this.weeklySchedule,
    required this.sessionDurationMinutes,
    required this.status,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String circleId;
  final String centerId;
  final String name;
  final String? description;
  final String educationalLevel;
  final String? assignedTeacherId;
  final int maxCapacity;

  /// Number of students currently enrolled. Kept in step with enrolment changes
  /// inside transactions; the Security Rules never let it exceed [maxCapacity].
  final int activeCount;
  final String locationOrMode; // onsite / online / hybrid
  final List<CircleWeeklySchedule> weeklySchedule;
  final int sessionDurationMinutes;
  final CircleStatus status;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get studentCount => 0; // populated by repository query, not stored here
  bool get hasCapacity =>
      true; // evaluated against enrollment count by repository

  Circle copyWith({
    String? name,
    String? description,
    String? educationalLevel,
    String? assignedTeacherId,
    int? maxCapacity,
    String? locationOrMode,
    List<CircleWeeklySchedule>? weeklySchedule,
    int? sessionDurationMinutes,
    CircleStatus? status,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Circle(
      circleId: circleId,
      centerId: centerId,
      name: name ?? this.name,
      description: description ?? this.description,
      educationalLevel: educationalLevel ?? this.educationalLevel,
      assignedTeacherId: assignedTeacherId ?? this.assignedTeacherId,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      activeCount: activeCount,
      locationOrMode: locationOrMode ?? this.locationOrMode,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      status: status ?? this.status,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Circle.fromJson(String circleId, JsonMap json) {
    return Circle(
      circleId: circleId,
      centerId: json['centerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      educationalLevel: json['educationalLevel'] as String? ?? '',
      assignedTeacherId: json['assignedTeacherId'] as String?,
      maxCapacity: json['maxCapacity'] as int? ?? 0,
      activeCount: json['activeCount'] as int? ?? 0,
      locationOrMode: json['locationOrMode'] as String? ?? '',
      weeklySchedule: (json['weeklySchedule'] as List<dynamic>?)
              ?.map((e) => CircleWeeklySchedule.fromJson(e as JsonMap))
              .toList() ??
          [],
      sessionDurationMinutes: json['sessionDurationMinutes'] as int? ?? 60,
      status: CircleStatusJson.fromJson(json['status'] as String?),
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
      'name': name,
      if (description != null) 'description': description,
      'educationalLevel': educationalLevel,
      if (assignedTeacherId != null) 'assignedTeacherId': assignedTeacherId,
      'maxCapacity': maxCapacity,
      'activeCount': activeCount,
      'locationOrMode': locationOrMode,
      'weeklySchedule': weeklySchedule.map((e) => e.toJson()).toList(),
      'sessionDurationMinutes': sessionDurationMinutes,
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
      other is Circle &&
          runtimeType == other.runtimeType &&
          circleId == other.circleId;

  @override
  int get hashCode => circleId.hashCode;

  @override
  String toString() =>
      'Circle(circleId: $circleId, name: $name, status: $status)';
}
