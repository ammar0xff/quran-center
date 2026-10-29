import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A teaching session instance (the live class).
class Session extends AppModel {
  const Session({
    required this.sessionId,
    required this.centerId,
    required this.circleId,
    this.scheduleId,
    required this.teacherId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.studentCount,
    required this.attendanceCompletedCount,
    required this.assessmentCompletedCount,
    this.isLocallyComplete = false,
    this.serverConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String centerId;
  final String circleId;
  final String? scheduleId;
  final String teacherId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final SessionStatus status;
  final int studentCount;
  final int attendanceCompletedCount;
  final int assessmentCompletedCount;
  final bool isLocallyComplete; // locally complete while sync pending
  final DateTime? serverConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isServerConfirmed => serverConfirmedAt != null;
  bool get isComplete => status == SessionStatus.completed;
  double get attendanceCompletionRate =>
      studentCount == 0 ? 0 : attendanceCompletedCount / studentCount;

  Session copyWith({
    SessionStatus? status,
    int? studentCount,
    int? attendanceCompletedCount,
    int? assessmentCompletedCount,
    bool? isLocallyComplete,
    DateTime? serverConfirmedAt,
    DateTime? updatedAt,
  }) {
    return Session(
      sessionId: sessionId,
      centerId: centerId,
      circleId: circleId,
      scheduleId: scheduleId,
      teacherId: teacherId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      status: status ?? this.status,
      studentCount: studentCount ?? this.studentCount,
      attendanceCompletedCount: attendanceCompletedCount ?? this.attendanceCompletedCount,
      assessmentCompletedCount: assessmentCompletedCount ?? this.assessmentCompletedCount,
      isLocallyComplete: isLocallyComplete ?? this.isLocallyComplete,
      serverConfirmedAt: serverConfirmedAt ?? this.serverConfirmedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Session.fromJson(String sessionId, JsonMap json) {
    return Session(
      sessionId: sessionId,
      centerId: json['centerId'] as String,
      circleId: json['circleId'] as String,
      scheduleId: json['scheduleId'] as String?,
      teacherId: json['teacherId'] as String,
      date: AppModel.parseDateTime(json['date']) ?? DateTime.now(),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      status: SessionStatusJson.fromJson(json['status'] as String?),
      studentCount: json['studentCount'] as int? ?? 0,
      attendanceCompletedCount: json['attendanceCompletedCount'] as int? ?? 0,
      assessmentCompletedCount: json['assessmentCompletedCount'] as int? ?? 0,
      isLocallyComplete: json['isLocallyComplete'] as bool? ?? false,
      serverConfirmedAt: AppModel.parseDateTime(json['serverConfirmedAt']),
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'circleId': circleId,
      if (scheduleId != null) 'scheduleId': scheduleId,
      'teacherId': teacherId,
      'date': AppModel.encodeDateTime(date),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.toJson(),
      'studentCount': studentCount,
      'attendanceCompletedCount': attendanceCompletedCount,
      'assessmentCompletedCount': assessmentCompletedCount,
      'isLocallyComplete': isLocallyComplete,
      if (serverConfirmedAt != null)
        'serverConfirmedAt': AppModel.encodeDateTime(serverConfirmedAt),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session && runtimeType == other.runtimeType && sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() =>
      'Session(sessionId: $sessionId, circleId: $circleId, status: $status)';
}
