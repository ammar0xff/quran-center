import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// Student educational profile.
///
/// A student is an educational entity, not an authentication account.
/// `authUserId` is optional and nullable — students may exist without login
/// credentials (children, elderly adults, non-technical users).
class Student extends AppModel {
  const Student({
    required this.studentId,
    required this.centerId,
    required this.fullName,
    this.preferredName,
    this.dateOfBirth,
    this.contactInfo,
    this.profileImageUrl,
    required this.enrollmentStatus,
    required this.accountMode,
    this.authUserId,
    required this.educationalLevel,
    this.accessibilityPreferences,
    this.currentCircleId,
    this.assignedTeacherIds = const [],
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String studentId;
  final String centerId;
  final String fullName;
  final String? preferredName;
  final DateTime? dateOfBirth;
  final Map<String, String>? contactInfo; // {phone?, guardianPhone?}
  final String? profileImageUrl;
  final EnrollmentStatus enrollmentStatus;
  final AccountMode accountMode;
  final String? authUserId; // links to users/{uid} when login enabled
  final String educationalLevel;
  final String? accessibilityPreferences;
  final String? currentCircleId; // maintained by enrolment changes

  /// The teachers who may see this student (set from the circle's teacher by
  /// enrolment changes; the Security Rules use it).
  final List<String> assignedTeacherIds;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => preferredName ?? fullName;
  bool get hasLogin =>
      accountMode == AccountMode.loginEnabled && authUserId != null;

  Student copyWith({
    String? fullName,
    String? preferredName,
    DateTime? dateOfBirth,
    Map<String, String>? contactInfo,
    String? profileImageUrl,
    EnrollmentStatus? enrollmentStatus,
    AccountMode? accountMode,
    String? authUserId,
    String? educationalLevel,
    String? accessibilityPreferences,
    String? currentCircleId,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return Student(
      studentId: studentId,
      centerId: centerId,
      fullName: fullName ?? this.fullName,
      preferredName: preferredName ?? this.preferredName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      contactInfo: contactInfo ?? this.contactInfo,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      accountMode: accountMode ?? this.accountMode,
      authUserId: authUserId ?? this.authUserId,
      educationalLevel: educationalLevel ?? this.educationalLevel,
      accessibilityPreferences:
          accessibilityPreferences ?? this.accessibilityPreferences,
      currentCircleId: currentCircleId ?? this.currentCircleId,
      assignedTeacherIds: assignedTeacherIds,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Student.fromJson(String studentId, JsonMap json) {
    return Student(
      studentId: studentId,
      centerId: json['centerId'] as String,
      fullName: json['fullName'] as String,
      preferredName: json['preferredName'] as String?,
      dateOfBirth: AppModel.parseDateTime(json['dateOfBirth']),
      contactInfo: (json['contactInfo'] as JsonMap?)
          ?.map((k, v) => MapEntry(k, v as String)),
      profileImageUrl: json['profileImageUrl'] as String?,
      enrollmentStatus:
          EnrollmentStatusJson.fromJson(json['enrollmentStatus'] as String?),
      accountMode: AccountModeJson.fromJson(json['accountMode'] as String?),
      authUserId: json['authUserId'] as String?,
      educationalLevel: json['educationalLevel'] as String? ?? '',
      accessibilityPreferences: json['accessibilityPreferences'] as String?,
      currentCircleId: json['currentCircleId'] as String?,
      assignedTeacherIds: [
        for (final t in (json['assignedTeacherIds'] as List? ?? const []))
          t as String
      ],
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
      'fullName': fullName,
      if (preferredName != null) 'preferredName': preferredName,
      if (dateOfBirth != null)
        'dateOfBirth': AppModel.encodeDateTime(dateOfBirth),
      if (contactInfo != null) 'contactInfo': contactInfo,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'enrollmentStatus': enrollmentStatus.toJson(),
      'accountMode': accountMode.toJson(),
      if (authUserId != null) 'authUserId': authUserId,
      'educationalLevel': educationalLevel,
      if (accessibilityPreferences != null)
        'accessibilityPreferences': accessibilityPreferences,
      if (currentCircleId != null) 'currentCircleId': currentCircleId,
      'assignedTeacherIds': assignedTeacherIds,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId;

  @override
  int get hashCode => studentId.hashCode;

  @override
  String toString() =>
      'Student(studentId: $studentId, fullName: $fullName, accountMode: $accountMode)';
}
