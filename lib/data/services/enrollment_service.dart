import 'package:quran_center/core/utils/enrollment_planner.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

/// An assignment that cannot proceed. [message] is user-facing Arabic.
class EnrollmentAssignmentException implements Exception {
  EnrollmentAssignmentException(this.message, {this.error});
  final String message;
  final AssignmentError? error;
  @override
  String toString() => message;
}

/// Assigns students to circles.
///
/// One assignment is a single atomic batch: the new enrolment, the closing of
/// any previous one (as `transferred`, never deleted), the student's
/// `assignedTeacherIds` (which the Security Rules use to let that teacher read
/// the student), and the audit entry. Either all of it happens or none.
///
/// Limitation: capacity is checked by reading, not by a transaction, so two
/// directors assigning the last seat at the same instant could both succeed.
class EnrollmentService {
  EnrollmentService(this._ds, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  static const _enrollments = 'enrollments';
  static const _timestampKeys = {
    'createdAt', 'updatedAt', 'startDate', 'endDate', 'changedAt',
  };

  Never _notFound() =>
      throw EnrollmentAssignmentException('لم يتم العثور على الطالب أو الحلقة.');

  /// Deterministic id: re-submitting the same assignment on the same day
  /// rewrites the same record instead of duplicating it.
  static String enrollmentId(String studentId, String circleId, DateTime start) {
    final d = '${start.year}${start.month.toString().padLeft(2, '0')}'
        '${start.day.toString().padLeft(2, '0')}';
    return 'enr_${studentId}_${circleId}_$d';
  }

  Future<Enrollment> assign({
    required String centerId,
    required String studentId,
    required String circleId,
    required String actorId,
    required String actorRole,
    required DateTime startDate,
    String? reason,
  }) async {
    final studentRaw = await _ds.getDoc('students/$studentId');
    final circleRaw = await _ds.getDoc('circles/$circleId');
    // Records of another center are indistinguishable from missing ones.
    if (studentRaw == null || studentRaw['centerId'] != centerId) _notFound();
    if (circleRaw == null || circleRaw['centerId'] != centerId) _notFound();

    final student = Student.fromJson(studentId, firestoreConverter.decodeFromRead(studentRaw));
    final circle = Circle.fromJson(circleId, firestoreConverter.decodeFromRead(circleRaw));

    final studentActive = (await _ds.query(_enrollments, where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
      QueryFilter.equal('status', 'active'),
    ]))
        .map((d) => Enrollment.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
    final circleCount = (await _ds.query(_enrollments, where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('circleId', circleId),
      QueryFilter.equal('status', 'active'),
    ]))
        .length;

    final result = planAssignment(
      student: student,
      circle: circle,
      studentActiveEnrollments: studentActive,
      circleActiveCount: circleCount,
    );
    if (result.error != null) {
      throw EnrollmentAssignmentException(
        assignmentErrorMessage(result.error!),
        error: result.error,
      );
    }
    final plan = result.plan!;

    final now = _now();
    final trimmed = reason?.trim();
    final transferReason =
        (trimmed == null || trimmed.isEmpty) ? 'نقل إلى حلقة أخرى' : trimmed;

    final created = Enrollment(
      enrollmentId: enrollmentId(studentId, circleId, startDate),
      centerId: centerId,
      studentId: studentId,
      circleId: circleId,
      teacherId: plan.teacherId,
      startDate: startDate,
      status: EnrollmentStatus.active,
      changeReason: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      changedBy: actorId,
      changedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final ops = <BatchOp>[
      for (final old in plan.toTransfer)
        BatchOp.update(
          '$_enrollments/${old.enrollmentId}',
          {
            ...firestoreConverter.encodeForWrite(
              {
                'endDate': startDate.millisecondsSinceEpoch,
                'changedAt': now.millisecondsSinceEpoch,
              },
              timestampKeys: _timestampKeys,
            ),
            'status': EnrollmentStatus.transferred.toJson(),
            'changeReason': transferReason,
            'changedBy': actorId,
            'updatedAt': firestoreConverter.serverTimestamp(),
          },
        ),
      BatchOp.set(
        '$_enrollments/${created.enrollmentId}',
        firestoreConverter.encodeForWrite(created.toJson(), timestampKeys: _timestampKeys),
      ),
      BatchOp.update('students/$studentId', {
        'assignedTeacherIds': plan.studentTeacherIds,
        'currentCircleId': circleId,
        'updatedBy': actorId,
        'updatedAt': firestoreConverter.serverTimestamp(),
      }),
      BatchOp.set('audit_logs/aud_${now.microsecondsSinceEpoch}_${studentId}_$circleId', {
        'centerId': centerId,
        'actorUserId': actorId,
        'actorRole': actorRole,
        'action': plan.toTransfer.isEmpty ? 'assign_student' : 'transfer_student',
        'entityType': 'student',
        'entityId': studentId,
        'previousValue': {
          'circleIds': plan.toTransfer.map((e) => e.circleId).toList(),
        },
        'newValue': {'circleId': circleId, 'teacherId': plan.teacherId},
        if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
        'createdAt': now.millisecondsSinceEpoch,
      }),
    ];
    // The circle's counter is the serialization point: the transaction reads it
    // fresh, re-checks the capacity, and writes the new count together with
    // everything else, so two directors taking the last seat cannot both win.
    final movedOut = <String, int>{};
    for (final old in plan.toTransfer) {
      movedOut[old.circleId] = (movedOut[old.circleId] ?? 0) + 1;
    }
    await _ds.runTransaction((tx) async {
      final target = await tx.get('circles/$circleId');
      final oldCircles = {
        for (final id in movedOut.keys) id: await tx.get('circles/$id'),
      };
      if (target == null || target['centerId'] != centerId) _notFound();
      final count = (target['activeCount'] as int?) ?? 0;
      final capacity = (target['maxCapacity'] as int?) ?? 0;
      if (count >= capacity) {
        throw EnrollmentAssignmentException(
          assignmentErrorMessage(AssignmentError.circleFull),
          error: AssignmentError.circleFull,
        );
      }
      for (final op in ops) {
        op.isUpdate ? tx.update(op.path, op.data) : tx.set(op.path, op.data);
      }
      tx.update('circles/$circleId', {'activeCount': count + 1});
      oldCircles.forEach((id, doc) {
        if (doc == null) return;
        final c = (doc['activeCount'] as int?) ?? 0;
        tx.update('circles/$id', {'activeCount': (c - movedOut[id]!).clamp(0, 1 << 30)});
      });
    });
    return created;
  }
}
