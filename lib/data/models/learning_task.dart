import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';

/// A student's self-reported practice claim (distinct from teacher verification).
class SelfReportedPractice {
  const SelfReportedPractice({
    required this.reportedAt,
    this.note,
    this.reflection,
  });

  final DateTime reportedAt;
  final String? note;
  final String? reflection;

  factory SelfReportedPractice.fromJson(JsonMap json) {
    return SelfReportedPractice(
      reportedAt: AppModel.parseDateTime(json['reportedAt']) ?? DateTime.now(),
      note: json['note'] as String?,
      reflection: json['reflection'] as String?,
    );
  }

  JsonMap toJson() {
    return {
      'reportedAt': AppModel.encodeDateTime(reportedAt),
      if (note != null) 'note': note,
      if (reflection != null) 'reflection': reflection,
    };
  }
}

/// A teacher's official verification of a task.
class TeacherVerification {
  const TeacherVerification({
    required this.verifiedAt,
    required this.verifiedBy,
    required this.result, // e.g. 'passed' / 'needs_improvement'
    this.feedback,
  });

  final DateTime verifiedAt;
  final String verifiedBy;
  final String result;
  final String? feedback;

  factory TeacherVerification.fromJson(JsonMap json) {
    return TeacherVerification(
      verifiedAt: AppModel.parseDateTime(json['verifiedAt']) ?? DateTime.now(),
      verifiedBy: json['verifiedBy'] as String,
      result: json['result'] as String,
      feedback: json['feedback'] as String?,
    );
  }

  JsonMap toJson() {
    return {
      'verifiedAt': AppModel.encodeDateTime(verifiedAt),
      'verifiedBy': verifiedBy,
      'result': result,
      if (feedback != null) 'feedback': feedback,
    };
  }
}

/// A learning task within a learning plan.
///
/// The student's `selfReportedPractice` is stored separately from the
/// teacher's `teacherVerification` — self-reported practice is never treated
/// as verified memorization.
class LearningTask extends AppModel {
  const LearningTask({
    required this.taskId,
    required this.centerId,
    required this.planId,
    required this.studentId,
    required this.teacherId,
    required this.taskType,
    required this.surah,
    required this.startAyah,
    required this.endAyah,
    required this.assignedDate,
    required this.dueDate,
    this.priority,
    required this.teacherInstructions,
    required this.status,
    this.selfReportedPractice,
    this.teacherVerification,
    this.completionMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String taskId;
  final String centerId;
  final String planId;
  final String studentId;
  final String teacherId;
  final TaskType taskType;
  final int surah;
  final int startAyah;
  final int endAyah;
  final DateTime assignedDate;
  final DateTime dueDate;
  final String? priority; // low | medium | high
  final String teacherInstructions;
  final TaskStatus status;
  final SelfReportedPractice? selfReportedPractice;
  final TeacherVerification? teacherVerification;
  final Map<String, dynamic>? completionMetadata; // {completedAt, verifiedAt}
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOverdue =>
      status != TaskStatus.completed &&
      status != TaskStatus.cancelled &&
      DateTime.now().isAfter(dueDate);

  bool get isVerified => teacherVerification != null;

  LearningTask copyWith({
    TaskStatus? status,
    SelfReportedPractice? selfReportedPractice,
    TeacherVerification? teacherVerification,
    Map<String, dynamic>? completionMetadata,
    DateTime? updatedAt,
  }) {
    return LearningTask(
      taskId: taskId,
      centerId: centerId,
      planId: planId,
      studentId: studentId,
      teacherId: teacherId,
      taskType: taskType,
      surah: surah,
      startAyah: startAyah,
      endAyah: endAyah,
      assignedDate: assignedDate,
      dueDate: dueDate,
      priority: priority,
      teacherInstructions: teacherInstructions,
      status: status ?? this.status,
      selfReportedPractice: selfReportedPractice ?? this.selfReportedPractice,
      teacherVerification: teacherVerification ?? this.teacherVerification,
      completionMetadata: completionMetadata ?? this.completionMetadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory LearningTask.fromJson(String taskId, JsonMap json) {
    return LearningTask(
      taskId: taskId,
      centerId: json['centerId'] as String,
      planId: json['planId'] as String,
      studentId: json['studentId'] as String,
      teacherId: json['teacherId'] as String,
      taskType: TaskTypeJson.fromJson(json['taskType'] as String?),
      surah: json['surah'] as int,
      startAyah: json['startAyah'] as int,
      endAyah: json['endAyah'] as int,
      assignedDate:
          AppModel.parseDateTime(json['assignedDate']) ?? DateTime.now(),
      dueDate: AppModel.parseDateTime(json['dueDate']) ?? DateTime.now(),
      priority: json['priority'] as String?,
      teacherInstructions: json['teacherInstructions'] as String,
      status: TaskStatusJson.fromJson(json['status'] as String?),
      selfReportedPractice: json['selfReportedPractice'] != null
          ? SelfReportedPractice.fromJson(
              json['selfReportedPractice'] as JsonMap)
          : null,
      teacherVerification: json['teacherVerification'] != null
          ? TeacherVerification.fromJson(json['teacherVerification'] as JsonMap)
          : null,
      completionMetadata: json['completionMetadata'] as Map<String, dynamic>?,
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'centerId': centerId,
      'planId': planId,
      'studentId': studentId,
      'teacherId': teacherId,
      'taskType': taskType.toJson(),
      'surah': surah,
      'startAyah': startAyah,
      'endAyah': endAyah,
      'assignedDate': AppModel.encodeDateTime(assignedDate),
      'dueDate': AppModel.encodeDateTime(dueDate),
      if (priority != null) 'priority': priority,
      'teacherInstructions': teacherInstructions,
      'status': status.toJson(),
      if (selfReportedPractice != null)
        'selfReportedPractice': selfReportedPractice!.toJson(),
      if (teacherVerification != null)
        'teacherVerification': teacherVerification!.toJson(),
      if (completionMetadata != null) 'completionMetadata': completionMetadata,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningTask &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId;

  @override
  int get hashCode => taskId.hashCode;

  @override
  String toString() =>
      'LearningTask(taskId: $taskId, studentId: $studentId, status: $status)';
}
