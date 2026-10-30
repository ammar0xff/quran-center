import 'package:quran_center/data/models/app_model.dart';

/// A notification delivered to an authenticated user.
///
/// No personal push notifications are created for accountless students.
/// Sensitive student details are never placed in the message payload.
class Notification extends AppModel {
  const Notification({
    required this.notificationId,
    required this.recipientUserId,
    required this.centerId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAt,
    this.read = false,
    this.readAt,
    this.deliveryMetadata,
  });

  final String notificationId;
  final String recipientUserId;
  final String centerId;
  final String
      type; // session_reminder | schedule_change | new_assignment | ...
  final String title;
  final String message;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;
  final bool read;
  final DateTime? readAt;
  final Map<String, dynamic>?
      deliveryMetadata; // {sentVia, messageId?, status?}

  Notification copyWith({
    bool? read,
    DateTime? readAt,
  }) {
    return Notification(
      notificationId: notificationId,
      recipientUserId: recipientUserId,
      centerId: centerId,
      type: type,
      title: title,
      message: message,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      createdAt: createdAt,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      deliveryMetadata: deliveryMetadata,
    );
  }

  factory Notification.fromJson(String notificationId, JsonMap json) {
    return Notification(
      notificationId: notificationId,
      recipientUserId: json['recipientUserId'] as String,
      centerId: json['centerId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      relatedEntityType: json['relatedEntityType'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      readAt: AppModel.parseDateTime(json['readAt']),
      deliveryMetadata: json['deliveryMetadata'] as Map<String, dynamic>?,
    );
  }

  @override
  JsonMap toJson() {
    return {
      'recipientUserId': recipientUserId,
      'centerId': centerId,
      'type': type,
      'title': title,
      'message': message,
      if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'read': read,
      if (readAt != null) 'readAt': AppModel.encodeDateTime(readAt),
      if (deliveryMetadata != null) 'deliveryMetadata': deliveryMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification &&
          runtimeType == other.runtimeType &&
          notificationId == other.notificationId;

  @override
  int get hashCode => notificationId.hashCode;

  @override
  String toString() =>
      'Notification(notificationId: $notificationId, type: $type, read: $read)';
}
