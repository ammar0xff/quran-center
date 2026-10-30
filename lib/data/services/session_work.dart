import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:quran_center/core/sync/outbox.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';

/// The teacher's in-session work (attendance, assessments), saved through a
/// durable [Outbox] so that a dropped connection never loses it.
///
/// Starting and finishing a session are NOT queued: they need the server's
/// answer (is it today? is everything saved?) and are refused while changes
/// for that session are still waiting.
class SessionWork {
  SessionWork(this._service, this.outbox);

  final TeacherSessionService _service;
  final Outbox outbox;

  static const attendanceType = 'attendance';
  static const assessmentType = 'assessment';

  /// Builds the work service together with the durable outbox of [owner].
  static SessionWork forOwner(
      TeacherSessionService service, OutboxStorage storage, String owner) {
    late SessionWork work;
    final box = Outbox(owner: owner, storage: storage, handlers: {
      attendanceType: (op) => work._sendAttendance(op),
      assessmentType: (op) => work._sendAssessment(op),
    });
    work = SessionWork(service, box);
    return work;
  }

  static String attendanceKey(String sessionId, String studentId) => 'att:$sessionId:$studentId';

  /// Anything wrong that retrying cannot fix becomes a permanent failure;
  /// network trouble is rethrown and retried later.
  Future<void> _guard(Future<void> Function() send) async {
    try {
      await send();
    } on SessionException catch (e) {
      throw PermanentOutboxFailure(e.message);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermanentOutboxFailure('رُفض الحفظ من الخادم. تواصل مع الإدارة إن تكرر ذلك.');
      }
      rethrow;
    }
  }

  Future<void> _sendAttendance(OutboxOp op) {
    final p = op.payload;
    return _guard(() => _service.record(
          centerId: p['centerId'] as String,
          teacherId: p['teacherId'] as String,
          sessionId: p['sessionId'] as String,
          studentId: p['studentId'] as String,
          status: AttendanceStatusJson.fromJson(p['status'] as String?),
          note: p['note'] as String?,
        ));
  }

  Future<void> _sendAssessment(OutboxOp op) {
    final p = op.payload;
    return _guard(() => _service.saveAssessment(
          centerId: p['centerId'] as String,
          teacherId: p['teacherId'] as String,
          sessionId: p['sessionId'] as String,
          studentId: p['studentId'] as String,
          recordId: p['recordId'] as String,
          assessedAt: DateTime.fromMillisecondsSinceEpoch(p['assessedAt'] as int),
          draft: AssessmentDraft.fromJson(Map<String, dynamic>.from(p['draft'] as Map)),
        ));
  }

  /// Saves locally at once and sends in the background.
  Future<void> markAttendance({
    required String centerId,
    required String teacherId,
    required String sessionId,
    required String studentId,
    required AttendanceStatus status,
    String? note,
    String? label,
  }) async {
    await outbox.enqueue(OutboxOp(
      key: attendanceKey(sessionId, studentId),
      type: attendanceType,
      scope: sessionId,
      createdAt: DateTime.now(),
      payload: {
        'centerId': centerId,
        'teacherId': teacherId,
        'sessionId': sessionId,
        'studentId': studentId,
        'status': status.toJson(),
        'note': note,
        if (label != null) 'label': label,
      },
    ));
    unawaited(outbox.flush());
  }

  Future<void> saveAssessment({
    required String centerId,
    required String teacherId,
    required String sessionId,
    required String studentId,
    required String recordId,
    required DateTime assessedAt,
    required AssessmentDraft draft,
    String? label,
  }) async {
    await outbox.enqueue(OutboxOp(
      key: 'asm:$recordId',
      type: assessmentType,
      scope: sessionId,
      createdAt: DateTime.now(),
      payload: {
        'centerId': centerId,
        'teacherId': teacherId,
        'sessionId': sessionId,
        'studentId': studentId,
        'recordId': recordId,
        'assessedAt': assessedAt.millisecondsSinceEpoch,
        'draft': draft.toJson(),
        if (label != null) 'label': label,
      },
    ));
    unawaited(outbox.flush());
  }

  /// Attendance changes for [sessionId] that have not reached the server, by
  /// student id (status shown to the teacher right away).
  Map<String, OutboxOp> pendingAttendance(String sessionId) => {
        for (final o in outbox.snapshot.inScope(sessionId))
          if (o.type == attendanceType) o.payload['studentId'] as String: o,
      };

  /// How many changes for [sessionId] are still waiting or were rejected.
  int unsyncedCount(String sessionId) => outbox.snapshot.inScope(sessionId).length;
}
