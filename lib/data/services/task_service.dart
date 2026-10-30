import 'package:quran_center/core/quran/surahs.dart';
import 'package:quran_center/core/utils/task_state.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/learning_plan.dart';
import 'package:quran_center/data/models/learning_task.dart';
import 'package:quran_center/data/services/notification_service.dart';

/// A task action that cannot proceed. [message] is user-facing Arabic.
class TaskException implements Exception {
  TaskException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A teacher's operations on learning tasks.
///
/// Tasks start as `upcoming` with no practice claim. Only [verify] can mark a
/// task completed, and it records who verified it and when; a student's
/// report can never do that. Every query carries the center and the teacher,
/// as the Security Rules require.
class TaskService {
  TaskService(this._ds, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  static const _taskTs = {'assignedDate', 'dueDate', 'createdAt', 'updatedAt'};
  static const _planTs = {'startDate', 'targetDate', 'createdAt', 'updatedAt'};

  static String planIdFor(String studentId, String teacherId) =>
      'plan_${studentId}_$teacherId';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<LearningTask> _task(
      String centerId, String teacherId, String taskId) async {
    final raw = await _ds.getDoc('learning_tasks/$taskId');
    if (raw == null ||
        raw['centerId'] != centerId ||
        raw['teacherId'] != teacherId) {
      throw TaskException('لم يتم العثور على المهمة.');
    }
    return LearningTask.fromJson(
        taskId, firestoreConverter.decodeFromRead(raw));
  }

  /// Assigns a task to one of the teacher's active students. [taskId] is fixed
  /// by the caller per form, so a retried save rewrites the same task.
  Future<void> assign({
    required String centerId,
    required String teacherId,
    required String studentId,
    required String taskId,
    required TaskType type,
    required int surah,
    required int startAyah,
    required int endAyah,
    required DateTime dueDate,
    String? instructions,
    String? priority,
  }) async {
    final rangeProblem = validateAyahRange(surah, startAyah, endAyah);
    if (rangeProblem != null) throw TaskException(rangeProblem);
    final today = _dateOnly(_now());
    final due = _dateOnly(dueDate);
    if (due.isBefore(today))
      throw TaskException('موعد التسليم لا يمكن أن يسبق اليوم.');
    if (priority != null && !{'low', 'medium', 'high'}.contains(priority)) {
      throw TaskException('أولوية غير صالحة.');
    }

    final enrolled = await _ds.query('enrollments', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
      QueryFilter.equal('status', 'active'),
      QueryFilter.equal('teacherId', teacherId),
    ]);
    if (enrolled.isEmpty) {
      throw TaskException('هذا الطالب ليس ضمن طلابك الحاليين.');
    }

    // The student's login, if they have one: only then is there someone to tell.
    final studentDoc = await _ds.getDoc('students/$studentId');
    final studentLogin = studentDoc?['authUserId'] as String?;

    final planId = planIdFor(studentId, teacherId);
    final plans = await _ds.query('learning_plans', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('responsibleTeacherId', teacherId),
      QueryFilter.equal('studentId', studentId),
    ]);

    final now = _now();
    final trimmed = instructions?.trim() ?? '';
    final task = LearningTask(
      taskId: taskId,
      centerId: centerId,
      planId: planId,
      studentId: studentId,
      teacherId: teacherId,
      taskType: type,
      surah: surah,
      startAyah: startAyah,
      endAyah: endAyah,
      assignedDate: today,
      dueDate: due,
      priority: priority,
      teacherInstructions: trimmed,
      status: TaskStatus.upcoming,
      createdAt: now,
      updatedAt: now,
    );

    await _ds.commitBatch([
      if (plans.isEmpty)
        BatchOp.set(
          'learning_plans/$planId',
          firestoreConverter.encodeForWrite(
            LearningPlan(
              planId: planId,
              centerId: centerId,
              studentId: studentId,
              responsibleTeacherId: teacherId,
              educationalObjective: 'متابعة الحفظ والمراجعة',
              startDate: today,
              targetDate: today.add(const Duration(days: 365)),
              status: PlanStatus.active,
              createdBy: teacherId,
              updatedBy: teacherId,
              createdAt: now,
              updatedAt: now,
            ).toJson(),
            timestampKeys: _planTs,
          ),
        ),
      BatchOp.set(
        'learning_tasks/$taskId',
        firestoreConverter.encodeForWrite(task.toJson(),
            timestampKeys: _taskTs),
      ),
      if (studentLogin != null)
        BatchOp.set(
          'notifications/${newNotificationId(now, studentLogin, 'asg')}',
          notificationDoc(
            centerId: centerId,
            recipientUserId: studentLogin,
            type: 'new_assignment',
            title: 'مهمة جديدة',
            message: 'أسند إليك معلمك مهمة جديدة. افتح «مهامي» لتراها.',
            relatedEntityType: 'student',
            relatedEntityId: studentId,
            now: now,
          ),
        ),
    ]);
  }

  /// Records the teacher's verification. `passed` completes the task;
  /// `needs_improvement` returns it for another attempt.
  Future<void> verify({
    required String centerId,
    required String teacherId,
    required String taskId,
    required String result,
    String? feedback,
  }) async {
    if (result != verificationPassed &&
        result != verificationNeedsImprovement) {
      throw TaskException('نتيجة غير صالحة.');
    }
    final task = await _task(centerId, teacherId, taskId);
    final to = statusForVerification(result);
    if (!canTransition(task.status, to, TaskActor.teacher)) {
      throw TaskException(
          'لا يمكن تغيير حالة هذه المهمة (${taskStatusLabel(task.status)}).');
    }
    final now = _now();
    final fb = feedback?.trim();
    final studentLogin = (await _ds
        .getDoc('students/${task.studentId}'))?['authUserId'] as String?;
    await _ds.commitBatch([
      BatchOp.update('learning_tasks/$taskId', {
        'status': to.toJson(),
        'teacherVerification': firestoreConverter.encodeForWrite(
          {
            'verifiedAt': now.millisecondsSinceEpoch,
            'verifiedBy': teacherId,
            'result': result,
            if (fb != null && fb.isNotEmpty) 'feedback': fb,
          },
          timestampKeys: {'verifiedAt'},
        ),
        'completionMetadata': firestoreConverter.encodeForWrite(
          {
            if (to == TaskStatus.completed)
              'completedAt': now.millisecondsSinceEpoch,
            'verifiedAt': now.millisecondsSinceEpoch,
          },
          timestampKeys: {'completedAt', 'verifiedAt'},
        ),
        'updatedAt': firestoreConverter.serverTimestamp(),
      }),
      if (studentLogin != null)
        BatchOp.set(
          'notifications/${newNotificationId(now, studentLogin, 'ver')}',
          notificationDoc(
            centerId: centerId,
            recipientUserId: studentLogin,
            type: 'teacher_feedback',
            title: to == TaskStatus.completed
                ? 'اعتمد معلمك مهمتك'
                : 'راجع معلمك مهمتك',
            message: to == TaskStatus.completed
                ? 'اعتمد المعلم إنجاز إحدى مهامك.'
                : 'طلب المعلم إعادة المحاولة في إحدى مهامك. افتحها لترى ملاحظته.',
            relatedEntityType: 'student',
            relatedEntityId: task.studentId,
            now: now,
          ),
        ),
    ]);
  }

  Future<void> cancel({
    required String centerId,
    required String teacherId,
    required String taskId,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) throw TaskException('سبب الإلغاء مطلوب.');
    final task = await _task(centerId, teacherId, taskId);
    if (!canTransition(task.status, TaskStatus.cancelled, TaskActor.teacher)) {
      throw TaskException(
          'لا يمكن إلغاء هذه المهمة (${taskStatusLabel(task.status)}).');
    }
    final now = _now();
    await _ds.updateDoc('learning_tasks/$taskId', {
      'status': TaskStatus.cancelled.toJson(),
      'completionMetadata': firestoreConverter.encodeForWrite(
        {
          'reason': why,
          'cancelledBy': teacherId,
          'cancelledAt': now.millisecondsSinceEpoch
        },
        timestampKeys: {'cancelledAt'},
      ),
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  Future<List<LearningTask>> tasksForStudent(
      String centerId, String teacherId, String studentId) async {
    final docs = await _ds.query('learning_tasks', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return _sorted(docs);
  }

  Future<List<LearningTask>> tasksForTeacher(
      String centerId, String teacherId) async {
    final docs = await _ds.query('learning_tasks', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
    ]);
    return _sorted(docs);
  }

  List<LearningTask> _sorted(List<Map<String, dynamic>> docs) {
    final list = docs
        .map((d) => LearningTask.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
    list.sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
    return list;
  }
}
