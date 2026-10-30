import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A scheduled teaching session (template or instance).
class Schedule extends AppModel {
  const Schedule({
    required this.scheduleId,
    required this.centerId,
    required this.circleId,
    required this.teacherId,
    required this.date, // date-only (start of day)
    required this.startTime, // HH:mm
    required this.endTime, // HH:mm
    required this.locationOrMode,
    required this.status,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.guestStudentIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String scheduleId;
  final String centerId;
  final String circleId;
  final String teacherId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String locationOrMode;
  final SessionStatus status;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  /// Students of other circles heard in this session by this teacher.
  final List<String> guestStudentIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Schedule copyWith({
    SessionStatus? status,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      scheduleId: scheduleId,
      centerId: centerId,
      circleId: circleId,
      teacherId: teacherId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      locationOrMode: locationOrMode,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      guestStudentIds: guestStudentIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Schedule.fromJson(String scheduleId, JsonMap json) {
    return Schedule(
      scheduleId: scheduleId,
      centerId: json['centerId'] as String,
      circleId: json['circleId'] as String,
      teacherId: json['teacherId'] as String,
      date: AppModel.parseDateTime(json['date']) ?? DateTime.now(),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      locationOrMode: json['locationOrMode'] as String? ?? '',
      status: SessionStatusJson.fromJson(json['status'] as String?),
      cancellationReason: json['cancellationReason'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      cancelledAt: AppModel.parseDateTime(json['cancelledAt']),
      guestStudentIds: [
        for (final g in (json['guestStudentIds'] as List? ?? const []))
          g as String
      ],
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'circleId': circleId,
      'teacherId': teacherId,
      'date': AppModel.encodeDateTime(date),
      'startTime': startTime,
      'endTime': endTime,
      'locationOrMode': locationOrMode,
      'status': status.toJson(),
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      if (cancelledAt != null)
        'cancelledAt': AppModel.encodeDateTime(cancelledAt),
      if (guestStudentIds.isNotEmpty) 'guestStudentIds': guestStudentIds,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Schedule &&
          runtimeType == other.runtimeType &&
          scheduleId == other.scheduleId;

  @override
  int get hashCode => scheduleId.hashCode;

  @override
  String toString() =>
      'Schedule(scheduleId: $scheduleId, circleId: $circleId, date: $date, status: $status)';
}
