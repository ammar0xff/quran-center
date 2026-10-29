import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A memorization / recitation assessment record.
///
/// `schemaVersion` allows historical records to remain interpretable after
/// the rubric evolves. Private teacher notes are stored separately from
/// student-visible feedback.
class MemorizationRecord extends AppModel {
  const MemorizationRecord({
    required this.recordId,
    required this.centerId,
    required this.studentId,
    required this.teacherId,
    this.sessionId,
    this.circleId,
    required this.assessmentType,
    required this.schemaVersion,
    required this.surah,
    required this.startAyah,
    required this.endAyah,
    required this.criteriaScores, // {criterionId: score}
    this.overallAssessment,
    required this.mistakesCount,
    this.mistakeCategory,
    this.mistakeReference,
    this.teacherCorrection,
    required this.requiresFollowUp,
    this.strengths,
    this.areasForImprovement,
    this.privateTeacherNote, // staff only
    this.studentVisibleFeedback,
    this.recommendedNextAssignment,
    this.suggestedNextReviewDate,
    required this.assessedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String recordId;
  final String centerId;
  final String studentId;
  final String teacherId;
  final String? sessionId;
  final String? circleId;
  final AssessmentType assessmentType;
  final int schemaVersion; // rubric version for historical interpretability
  final int surah; // 1-114
  final int startAyah;
  final int endAyah;
  final Map<String, double> criteriaScores;
  final String? overallAssessment;
  final int mistakesCount;
  final String? mistakeCategory;
  final String? mistakeReference;
  final String? teacherCorrection;
  final bool requiresFollowUp;
  final String? strengths;
  final String? areasForImprovement;
  final String? privateTeacherNote;
  final String? studentVisibleFeedback;
  final String? recommendedNextAssignment;
  final DateTime? suggestedNextReviewDate;
  final DateTime assessedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemorizationRecord copyWith({
    AssessmentType? assessmentType,
    int? surah,
    int? startAyah,
    int? endAyah,
    Map<String, double>? criteriaScores,
    String? overallAssessment,
    int? mistakesCount,
    String? mistakeCategory,
    String? mistakeReference,
    String? teacherCorrection,
    bool? requiresFollowUp,
    String? strengths,
    String? areasForImprovement,
    String? privateTeacherNote,
    String? studentVisibleFeedback,
    String? recommendedNextAssignment,
    DateTime? suggestedNextReviewDate,
    DateTime? assessedAt,
    DateTime? updatedAt,
  }) {
    return MemorizationRecord(
      recordId: recordId,
      centerId: centerId,
      studentId: studentId,
      teacherId: teacherId,
      sessionId: sessionId,
      circleId: circleId,
      assessmentType: assessmentType ?? this.assessmentType,
      schemaVersion: schemaVersion,
      surah: surah ?? this.surah,
      startAyah: startAyah ?? this.startAyah,
      endAyah: endAyah ?? this.endAyah,
      criteriaScores: criteriaScores ?? this.criteriaScores,
      overallAssessment: overallAssessment ?? this.overallAssessment,
      mistakesCount: mistakesCount ?? this.mistakesCount,
      mistakeCategory: mistakeCategory ?? this.mistakeCategory,
      mistakeReference: mistakeReference ?? this.mistakeReference,
      teacherCorrection: teacherCorrection ?? this.teacherCorrection,
      requiresFollowUp: requiresFollowUp ?? this.requiresFollowUp,
      strengths: strengths ?? this.strengths,
      areasForImprovement: areasForImprovement ?? this.areasForImprovement,
      privateTeacherNote: privateTeacherNote ?? this.privateTeacherNote,
      studentVisibleFeedback: studentVisibleFeedback ?? this.studentVisibleFeedback,
      recommendedNextAssignment:
          recommendedNextAssignment ?? this.recommendedNextAssignment,
      suggestedNextReviewDate:
          suggestedNextReviewDate ?? this.suggestedNextReviewDate,
      assessedAt: assessedAt ?? this.assessedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory MemorizationRecord.fromJson(String recordId, JsonMap json) {
    return MemorizationRecord(
      recordId: recordId,
      centerId: json['centerId'] as String,
      studentId: json['studentId'] as String,
      teacherId: json['teacherId'] as String,
      sessionId: json['sessionId'] as String?,
      circleId: json['circleId'] as String?,
      assessmentType: AssessmentTypeJson.fromJson(json['assessmentType'] as String?),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      surah: json['surah'] as int,
      startAyah: json['startAyah'] as int,
      endAyah: json['endAyah'] as int,
      criteriaScores:
          (json['criteriaScores'] as JsonMap?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      overallAssessment: json['overallAssessment'] as String?,
      mistakesCount: json['mistakesCount'] as int? ?? 0,
      mistakeCategory: json['mistakeCategory'] as String?,
      mistakeReference: json['mistakeReference'] as String?,
      teacherCorrection: json['teacherCorrection'] as String?,
      requiresFollowUp: json['requiresFollowUp'] as bool? ?? false,
      strengths: json['strengths'] as String?,
      areasForImprovement: json['areasForImprovement'] as String?,
      privateTeacherNote: json['privateTeacherNote'] as String?,
      studentVisibleFeedback: json['studentVisibleFeedback'] as String?,
      recommendedNextAssignment: json['recommendedNextAssignment'] as String?,
      suggestedNextReviewDate: AppModel.parseDateTime(json['suggestedNextReviewDate']),
      assessedAt: AppModel.parseDateTime(json['assessedAt']) ?? DateTime.now(),
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'studentId': studentId,
      'teacherId': teacherId,
      if (sessionId != null) 'sessionId': sessionId,
      if (circleId != null) 'circleId': circleId,
      'assessmentType': assessmentType.toJson(),
      'schemaVersion': schemaVersion,
      'surah': surah,
      'startAyah': startAyah,
      'endAyah': endAyah,
      'criteriaScores': criteriaScores,
      if (overallAssessment != null) 'overallAssessment': overallAssessment,
      'mistakesCount': mistakesCount,
      if (mistakeCategory != null) 'mistakeCategory': mistakeCategory,
      if (mistakeReference != null) 'mistakeReference': mistakeReference,
      if (teacherCorrection != null) 'teacherCorrection': teacherCorrection,
      'requiresFollowUp': requiresFollowUp,
      if (strengths != null) 'strengths': strengths,
      if (areasForImprovement != null) 'areasForImprovement': areasForImprovement,
      if (privateTeacherNote != null) 'privateTeacherNote': privateTeacherNote,
      if (studentVisibleFeedback != null)
        'studentVisibleFeedback': studentVisibleFeedback,
      if (recommendedNextAssignment != null)
        'recommendedNextAssignment': recommendedNextAssignment,
      if (suggestedNextReviewDate != null)
        'suggestedNextReviewDate': AppModel.encodeDateTime(suggestedNextReviewDate),
      'assessedAt': AppModel.encodeDateTime(assessedAt),
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemorizationRecord &&
          runtimeType == other.runtimeType &&
          recordId == other.recordId;

  @override
  int get hashCode => recordId.hashCode;

  @override
  String toString() =>
      'MemorizationRecord(recordId: $recordId, studentId: $studentId, surah: $surah)';
}
