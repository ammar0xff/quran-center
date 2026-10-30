import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/repositories/attendance_repository.dart';
import 'package:quran_center/data/repositories/impl/audit_repository_impl.dart';

/// Firestore-backed [AttendanceRepository]. Collection: `attendance/{id}`
/// where id = [attendanceDocId] (one record per student per session).
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._ds, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  static const _collectionPath = 'attendance';
  static const _timestampKeys = {'createdAt', 'updatedAt'};

  String _path(String sessionId, String studentId) =>
      '$_collectionPath/${attendanceDocId(sessionId, studentId)}';

  Attendance _fromMap(Map<String, dynamic> d) =>
      Attendance.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d));

  @override
  Future<void> record(Attendance attendance) async {
    final id = attendanceDocId(attendance.sessionId, attendance.studentId);
    final path = '$_collectionPath/$id';
    final existing = await _ds.getDoc(path);
    if (existing != null) {
      final same = existing['status'] == attendance.status.toJson() &&
          existing['recordedBy'] == attendance.recordedBy;
      if (same) return; // idempotent retry
      throw DuplicateAttendanceException(id);
    }
    final data = firestoreConverter.encodeForWrite(
      attendance.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc(path, data);
  }

  @override
  Future<List<Attendance>> getBySession(String sessionId) async {
    final docs = await _ds.query(_collectionPath,
        where: [QueryFilter.equal('sessionId', sessionId)]);
    return docs.map(_fromMap).toList();
  }

  @override
  Future<List<Attendance>> getByStudent(String studentId,
      {required String centerId}) async {
    final docs = await _ds.query(_collectionPath, where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return docs.map(_fromMap).toList();
  }

  @override
  Future<List<Attendance>> getByCenter(String centerId) async {
    final docs = await _ds.query(_collectionPath,
        where: [QueryFilter.equal('centerId', centerId)]);
    return docs.map(_fromMap).toList();
  }

  @override
  Future<void> correct({
    required String sessionId,
    required String studentId,
    required AttendanceStatus newStatus,
    required String actorId,
    required String actorRole,
    required String reason,
  }) async {
    final path = _path(sessionId, studentId);
    final raw = await _ds.getDoc(path);
    if (raw == null) {
      throw AttendanceCorrectionException('لا يوجد سجل حضور لتصحيحه');
    }
    final current = Attendance.fromJson(
        attendanceDocId(sessionId, studentId), firestoreConverter.decodeFromRead(raw));

    final problem = validateCorrection(
      current: current.status,
      requested: newStatus,
      reason: reason,
    );
    if (problem != null) {
      throw AttendanceCorrectionException(
        problem == CorrectionError.reasonRequired
            ? 'سبب التصحيح مطلوب'
            : 'الحالة الجديدة مطابقة للحالة الحالية',
        error: problem,
      );
    }

    final now = _now();
    // Keep the very first original status across repeated corrections.
    final originalStatus =
        current.correctionMetadata?.originalStatus ?? current.status;
    final correction = AttendanceCorrection(
      originalStatus: originalStatus,
      correctedBy: actorId,
      correctedAt: now,
      reason: reason.trim(),
    );

    final auditId = 'aud_${now.microsecondsSinceEpoch}_${sessionId}_$studentId';
    await _ds.commitBatch([
      BatchOp.update(path, {
        'status': newStatus.toJson(),
        'correctionMetadata': correction.toJson(),
        'updatedAt': firestoreConverter.serverTimestamp(),
      }),
      BatchOp.set('${AuditRepositoryImpl.collectionPath}/$auditId', {
        'centerId': current.centerId,
        'actorUserId': actorId,
        'actorRole': actorRole,
        'action': 'correct_attendance',
        'entityType': 'attendance',
        'entityId': attendanceDocId(sessionId, studentId),
        'previousValue': {'status': current.status.toJson()},
        'newValue': {'status': newStatus.toJson()},
        'reason': reason.trim(),
        'createdAt': now.millisecondsSinceEpoch,
      }),
    ]);
  }
}
