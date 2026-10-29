import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A Quran teacher (محفظ / محفظة).
class Teacher extends AppModel {
  const Teacher({
    required this.teacherId,
    required this.centerId,
    this.userId, // links to users/{uid} when account provisioned
    required this.fullName,
    this.contactInfo, // {phone?, email?}
    this.profileImageUrl,
    this.professionalNotes,
    required this.status,
    required this.assignedCircleIds,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String teacherId;
  final String centerId;
  final String? userId;
  final String fullName;
  final Map<String, String>? contactInfo;
  final String? profileImageUrl;
  final String? professionalNotes;
  final AccountStatus status;
  final List<String> assignedCircleIds;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == AccountStatus.active;
  bool get hasAccount => userId != null;

  Teacher copyWith({
    String? fullName,
    Map<String, String>? contactInfo,
    String? profileImageUrl,
    String? professionalNotes,
    AccountStatus? status,
    List<String>? assignedCircleIds,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Teacher(
      teacherId: teacherId,
      centerId: centerId,
      userId: userId,
      fullName: fullName ?? this.fullName,
      contactInfo: contactInfo ?? this.contactInfo,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      professionalNotes: professionalNotes ?? this.professionalNotes,
      status: status ?? this.status,
      assignedCircleIds: assignedCircleIds ?? this.assignedCircleIds,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Teacher.fromJson(String teacherId, JsonMap json) {
    return Teacher(
      teacherId: teacherId,
      centerId: json['centerId'] as String,
      userId: json['userId'] as String?,
      fullName: json['fullName'] as String,
      contactInfo: (json['contactInfo'] as JsonMap?)
          ?.map((k, v) => MapEntry(k, v as String)),
      profileImageUrl: json['profileImageUrl'] as String?,
      professionalNotes: json['professionalNotes'] as String?,
      status: AccountStatusJson.fromJson(json['status'] as String?),
      assignedCircleIds:
          (json['assignedCircleIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
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
      if (userId != null) 'userId': userId,
      'fullName': fullName,
      if (contactInfo != null) 'contactInfo': contactInfo,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (professionalNotes != null) 'professionalNotes': professionalNotes,
      'status': status.toJson(),
      'assignedCircleIds': assignedCircleIds,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Teacher && runtimeType == other.runtimeType && teacherId == other.teacherId;

  @override
  int get hashCode => teacherId.hashCode;

  @override
  String toString() => 'Teacher(teacherId: $teacherId, fullName: $fullName, status: $status)';
}
