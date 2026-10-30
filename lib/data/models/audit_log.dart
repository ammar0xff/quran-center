import 'package:quran_center/data/models/app_model.dart';

/// An immutable audit log entry for sensitive operations.
class AuditLog extends AppModel {
  const AuditLog({
    required this.auditId,
    required this.centerId,
    this.actorUserId,
    this.actorRole,
    required this.action, // e.g. create_student, correct_attendance, link_account
    required this.entityType,
    required this.entityId,
    this.previousValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  final String auditId;
  final String centerId;
  final String? actorUserId;
  final String? actorRole;
  final String action;
  final String entityType;
  final String entityId;
  final JsonMap? previousValue;
  final JsonMap? newValue;
  final String? reason;
  final DateTime createdAt;

  factory AuditLog.fromJson(String auditId, JsonMap json) {
    return AuditLog(
      auditId: auditId,
      centerId: json['centerId'] as String,
      actorUserId: json['actorUserId'] as String?,
      actorRole: json['actorRole'] as String?,
      action: json['action'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      previousValue: json['previousValue'] as JsonMap?,
      newValue: json['newValue'] as JsonMap?,
      reason: json['reason'] as String?,
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      if (actorUserId != null) 'actorUserId': actorUserId,
      if (actorRole != null) 'actorRole': actorRole,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      if (previousValue != null) 'previousValue': previousValue,
      if (newValue != null) 'newValue': newValue,
      if (reason != null) 'reason': reason,
      'createdAt': AppModel.encodeDateTime(createdAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLog &&
          runtimeType == other.runtimeType &&
          auditId == other.auditId;

  @override
  int get hashCode => auditId.hashCode;

  @override
  String toString() =>
      'AuditLog(auditId: $auditId, action: $action, entity: $entityType/$entityId)';
}
