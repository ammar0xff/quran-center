import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// Authoritative user profile stored in `users/{uid}`.
///
/// The `role` field is written only by trusted provisioning workflows /
/// custom claims. Clients cannot self-assign roles.
class User extends AppModel {
  const User({
    required this.uid,
    required this.centerId,
    required this.fullName,
    required this.role,
    required this.status,
    required this.authProvider,
    this.phone,
    this.profileImageUrl,
    this.assignedCenterIds = const [],
    this.studentId,
    this.lastSignInAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String centerId;
  final String fullName;
  final UserRole role;
  final AccountStatus status;
  final String authProvider;
  final String? phone;
  final String? profileImageUrl;
  final List<String> assignedCenterIds;

  /// For student accounts: the student profile this login belongs to.
  final String? studentId;
  final DateTime? lastSignInAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == AccountStatus.active;
  bool get isDirector => role == UserRole.director;
  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;

  User copyWith({
    String? centerId,
    String? fullName,
    UserRole? role,
    AccountStatus? status,
    String? authProvider,
    String? phone,
    String? profileImageUrl,
    List<String>? assignedCenterIds,
    DateTime? lastSignInAt,
    DateTime? updatedAt,
  }) {
    return User(
      uid: uid,
      centerId: centerId ?? this.centerId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      authProvider: authProvider ?? this.authProvider,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      assignedCenterIds: assignedCenterIds ?? this.assignedCenterIds,
      studentId: studentId,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory User.fromJson(String uid, JsonMap json) {
    return User(
      uid: uid,
      centerId: json['centerId'] as String,
      fullName: json['fullName'] as String,
      role: UserRoleJson.fromJson(json['role'] as String?),
      status: AccountStatusJson.fromJson(json['status'] as String?),
      authProvider: json['authProvider'] as String? ?? 'anonymous',
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      assignedCenterIds: (json['assignedCenterIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      studentId: json['studentId'] as String?,
      lastSignInAt: AppModel.parseDateTime(json['lastSignInAt']),
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'fullName': fullName,
      'role': role.toJson(),
      'status': status.toJson(),
      'authProvider': authProvider,
      if (phone != null) 'phone': phone,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'assignedCenterIds': assignedCenterIds,
      if (studentId != null) 'studentId': studentId,
      if (lastSignInAt != null)
        'lastSignInAt': AppModel.encodeDateTime(lastSignInAt),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          centerId == other.centerId &&
          fullName == other.fullName &&
          role == other.role &&
          status == other.status &&
          authProvider == other.authProvider &&
          phone == other.phone &&
          profileImageUrl == other.profileImageUrl &&
          studentId == other.studentId &&
          assignedCenterIds.length == other.assignedCenterIds.length &&
          assignedCenterIds.asMap().entries.every(
                (entry) => entry.value == other.assignedCenterIds[entry.key],
              ) &&
          lastSignInAt == other.lastSignInAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        uid,
        centerId,
        fullName,
        role,
        status,
        authProvider,
        phone,
        profileImageUrl,
        Object.hashAll(assignedCenterIds),
        studentId,
        lastSignInAt,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'User(uid: $uid, fullName: $fullName, role: $role, status: $status)';
}
