import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';

/// A student-side action that cannot proceed. [message] is user-facing Arabic.
class StudentActionException implements Exception {
  StudentActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything a student account reads or does, scoped to that one student.
///
/// Queries carry the center and the student id, as the Security Rules require.
/// A student can only start a task and *report* practice; completion is the
/// teacher's verification and is never reachable from here.
class StudentWorkspace {
  StudentWorkspace(this._ds, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  Future<Student?> profile(String centerId, String studentId) async {
    final raw = await _ds.getDoc('students/$studentId');
    if (raw == null || raw['centerId'] != centerId) return null;
    return Student.fromJson(studentId, firestoreConverter.decodeFromRead(raw));
  }

  Future<Circle?> circle(String centerId, String? circleId) async {
    if (circleId == null) return null;
    final raw = await _ds.getDoc('circles/$circleId');
    if (raw == null || raw['centerId'] != centerId) return null;
    return Circle.fromJson(circleId, firestoreConverter.decodeFromRead(raw));
  }

  Future<List<Schedule>> sessions(String centerId, String? circleId) async {
    if (circleId == null) return [];
    final docs = await _ds.query('schedules', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('circleId', circleId),
    ]);
    final list = docs
        .map((d) => Schedule.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
    return list;
  }

  Future<List<LearningTask>> tasks(String centerId, String studentId) async {
    final docs = await _ds.query('learning_tasks', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return docs
        .map((d) => LearningTask.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<List<MemorizationRecord>> feedback(String centerId, String studentId) async {
    final docs = await _ds.query('memorization_records', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return docs
        .map((d) => MemorizationRecord.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList()
      ..sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
  }

  Future<LearningTask> _task(String centerId, String studentId, String taskId) async {
    final raw = await _ds.getDoc('learning_tasks/$taskId');
    if (raw == null || raw['centerId'] != centerId || raw['studentId'] != studentId) {
      throw StudentActionException('لم يتم العثور على المهمة.');
    }
    return LearningTask.fromJson(taskId, firestoreConverter.decodeFromRead(raw));
  }

  Future<void> _move(LearningTask t, TaskStatus to, Map<String, dynamic> extra) async {
    if (!canTransition(t.status, to, TaskActor.student)) {
      throw StudentActionException(
          'لا يمكن تنفيذ ذلك والمهمة في حالة «${taskStatusLabel(t.status)}».');
    }
    await _ds.updateDoc('learning_tasks/${t.taskId}', {
      'status': to.toJson(),
      ...extra,
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  /// "I started working on it."
  Future<void> start(String centerId, String studentId, String taskId) async {
    final t = await _task(centerId, studentId, taskId);
    await _move(t, TaskStatus.inProgress, const {});
  }

  /// "I practiced." Recorded as the student's claim; the teacher still has to
  /// verify before the task counts as completed.
  Future<void> reportPractice(String centerId, String studentId, String taskId,
      {String? reflection}) async {
    final t = await _task(centerId, studentId, taskId);
    final r = reflection?.trim();
    await _move(t, TaskStatus.practiceReported, {
      'selfReportedPractice': firestoreConverter.encodeForWrite(
        {
          'reportedAt': _now().millisecondsSinceEpoch,
          if (r != null && r.isNotEmpty) 'reflection': r,
        },
        timestampKeys: {'reportedAt'},
      ),
    });
  }

  /// Hand the practice over for the teacher to review.
  Future<void> submitForReview(String centerId, String studentId, String taskId) async {
    final t = await _task(centerId, studentId, taskId);
    await _move(t, TaskStatus.submittedForReview, const {});
  }
}
