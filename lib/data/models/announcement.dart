import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A center announcement targeted at an audience.
class Announcement extends AppModel {
  const Announcement({
    required this.announcementId,
    required this.centerId,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.targetEntityIds,
    required this.authorId,
    required this.status,
    this.publishAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String announcementId;
  final String centerId;
  final String title;
  final String message;
  final AudienceType targetAudience;
  final List<String> targetEntityIds; // circles or users
  final String authorId;
  final AnnouncementStatus status;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => status == AnnouncementStatus.published;

  Announcement copyWith({
    String? title,
    String? message,
    AudienceType? targetAudience,
    List<String>? targetEntityIds,
    AnnouncementStatus? status,
    DateTime? publishAt,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) {
    return Announcement(
      announcementId: announcementId,
      centerId: centerId,
      title: title ?? this.title,
      message: message ?? this.message,
      targetAudience: targetAudience ?? this.targetAudience,
      targetEntityIds: targetEntityIds ?? this.targetEntityIds,
      authorId: authorId,
      status: status ?? this.status,
      publishAt: publishAt ?? this.publishAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Announcement.fromJson(String announcementId, JsonMap json) {
    return Announcement(
      announcementId: announcementId,
      centerId: json['centerId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      targetAudience:
          AudienceTypeJson.fromJson(json['targetAudience'] as String?),
      targetEntityIds: (json['targetEntityIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      authorId: json['authorId'] as String,
      status: AnnouncementStatusJson.fromJson(json['status'] as String?),
      publishAt: AppModel.parseDateTime(json['publishAt']),
      expiresAt: AppModel.parseDateTime(json['expiresAt']),
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'title': title,
      'message': message,
      'targetAudience': targetAudience.toJson(),
      'targetEntityIds': targetEntityIds,
      'authorId': authorId,
      'status': status.toJson(),
      if (publishAt != null) 'publishAt': AppModel.encodeDateTime(publishAt),
      if (expiresAt != null) 'expiresAt': AppModel.encodeDateTime(expiresAt),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Announcement &&
          runtimeType == other.runtimeType &&
          announcementId == other.announcementId;

  @override
  int get hashCode => announcementId.hashCode;

  @override
  String toString() =>
      'Announcement(announcementId: $announcementId, title: $title, status: $status)';
}
