import 'package:quran_center/data/models/app_model.dart';

/// Center-wide configuration (assessment criteria, scales, permissions, branding).
class CenterSetting extends AppModel {
  const CenterSetting({
    required this.centerId,
    required this.assessmentCriteria, // [criterionId]
    required this.scoringScale, // map
    required this.attendanceStatuses, // [present, absent, late, excused]
    required this.defaultSessionDurationMinutes,
    required this.learningTaskDefaults, // map
    required this.reminderRules, // map
    required this.permissions, // {whoCanCorrectAttendance, ...}
    required this.updatedAt,
    required this.updatedBy,
  });

  final String centerId;
  final List<String> assessmentCriteria;
  final Map<String, dynamic> scoringScale;
  final List<String> attendanceStatuses;
  final int defaultSessionDurationMinutes;
  final Map<String, dynamic> learningTaskDefaults;
  final Map<String, dynamic> reminderRules;
  final Map<String, dynamic> permissions;
  final DateTime updatedAt;
  final String updatedBy;

  factory CenterSetting.fromJson(JsonMap json) {
    return CenterSetting(
      centerId: json['centerId'] as String,
      assessmentCriteria: (json['assessmentCriteria'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      scoringScale: json['scoringScale'] as Map<String, dynamic>? ?? {},
      attendanceStatuses: (json['attendanceStatuses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['present', 'absent', 'late', 'excused'],
      defaultSessionDurationMinutes:
          json['defaultSessionDurationMinutes'] as int? ?? 60,
      learningTaskDefaults:
          json['learningTaskDefaults'] as Map<String, dynamic>? ?? {},
      reminderRules: json['reminderRules'] as Map<String, dynamic>? ?? {},
      permissions: json['permissions'] as Map<String, dynamic>? ?? {},
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
      updatedBy: json['updatedBy'] as String,
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'assessmentCriteria': assessmentCriteria,
      'scoringScale': scoringScale,
      'attendanceStatuses': attendanceStatuses,
      'defaultSessionDurationMinutes': defaultSessionDurationMinutes,
      'learningTaskDefaults': learningTaskDefaults,
      'reminderRules': reminderRules,
      'permissions': permissions,
      'updatedAt': AppModel.encodeDateTime(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CenterSetting &&
          runtimeType == other.runtimeType &&
          centerId == other.centerId;

  @override
  int get hashCode => centerId.hashCode;

  @override
  String toString() => 'CenterSetting(centerId: $centerId)';
}
