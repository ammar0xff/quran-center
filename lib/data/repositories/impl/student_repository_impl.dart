import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/repositories/student_repository.dart';

/// Firestore-backed implementation of [StudentRepository].
///
/// Collection: `students/{studentId}`.
class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'students';
  static const _timestampKeys = {'createdAt', 'updatedAt', 'dateOfBirth'};

  @override
  Future<Student?> getStudent(String studentId) async {
    final data = await _ds.getDoc('$_collectionPath/$studentId');
    if (data == null) return null;
    return Student.fromJson(studentId, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createStudent(Student student) async {
    final data = firestoreConverter.encodeForWrite(
      student.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${student.studentId}', data);
  }

  @override
  Future<void> updateStudent(Student student) async {
    final data = firestoreConverter.encodeForWrite(
      student.toJson()..removeWhere((k, v) => k == 'studentId'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${student.studentId}', data);
  }

  @override
  Future<void> archiveStudent(
    String studentId, {
    required String actorId,
    required String actorRole,
    String? reason,
  }) =>
      _changeEnrollmentStatus(
        studentId,
        to: EnrollmentStatus.archived,
        action: 'archive_student',
        actorId: actorId,
        actorRole: actorRole,
        reason: reason,
      );

  @override
  Future<String?> getAdminNote(String studentId, {required String centerId}) async {
    final docs = await _ds.query('student_admin_notes', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ]);
    if (docs.isEmpty) return null;
    final note = (docs.first['note'] as String?)?.trim();
    return (note == null || note.isEmpty) ? null : note;
  }

  @override
  Future<bool> updateProfile(
    String studentId, {
    required String actorId,
    required String actorRole,
    required String fullName,
    String? preferredName,
    required String educationalLevel,
    String? adminNotes,
  }) async {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final name = clean(fullName);
    final level = clean(educationalLevel);
    if (name == null) throw ArgumentError('fullName is required');
    if (level == null) throw ArgumentError('educationalLevel is required');

    final path = '$_collectionPath/$studentId';
    final current = await _ds.getDoc(path);
    if (current == null) throw StateError('Student not found: $studentId');

    final wanted = <String, String?>{
      'fullName': name,
      'preferredName': clean(preferredName),
      'educationalLevel': level,
    };
    final previous = <String, dynamic>{};
    final next = <String, dynamic>{};
    wanted.forEach((key, value) {
      final before = current[key] as String?;
      if (before != value) {
        previous[key] = before;
        next[key] = value;
      }
    });

    final centerId = current['centerId'] as String;
    // null = leave the note alone; blank = clear it.
    final noteBefore = adminNotes == null
        ? null
        : await getAdminNote(studentId, centerId: centerId);
    final noteAfter = clean(adminNotes);
    final noteChanged = adminNotes != null && noteBefore != noteAfter;
    if (noteChanged) {
      previous['adminNotes'] = noteBefore;
      next['adminNotes'] = noteAfter;
    }
    if (next.isEmpty) return false;

    final now = DateTime.now();
    final studentFields = {
      for (final e in next.entries)
        if (e.key != 'adminNotes') e.key: e.value,
    };
    await _ds.commitBatch([
      if (studentFields.isNotEmpty)
        BatchOp.update(path, {
          ...studentFields,
          'updatedBy': actorId,
          'updatedAt': firestoreConverter.serverTimestamp(),
        }),
      if (noteChanged)
        BatchOp.set('student_admin_notes/$studentId', {
          'centerId': centerId,
          'studentId': studentId,
          'note': noteAfter ?? '',
          'updatedBy': actorId,
          'updatedAt': firestoreConverter.serverTimestamp(),
        }),
      BatchOp.set('audit_logs/aud_${now.microsecondsSinceEpoch}_$studentId', {
        'centerId': centerId,
        'actorUserId': actorId,
        'actorRole': actorRole,
        'action': 'update_student',
        'entityType': 'student',
        'entityId': studentId,
        'previousValue': previous,
        'newValue': next,
        'createdAt': now.millisecondsSinceEpoch,
      }),
    ]);
    return true;
  }

  @override
  Future<void> reinstateStudent(
    String studentId, {
    required String actorId,
    required String actorRole,
    String? reason,
  }) =>
      _changeEnrollmentStatus(
        studentId,
        to: EnrollmentStatus.active,
        action: 'reinstate_student',
        actorId: actorId,
        actorRole: actorRole,
        reason: reason,
      );

  /// Changes the enrolment status and writes the audit entry in one atomic
  /// batch. Archiving also ends the student's current circle enrolment (kept as
  /// history, closed as `withdrawn`) and clears their assigned teacher and
  /// current circle, so an archived student no longer takes a seat or appears
  /// on a teacher's roster. Reinstating does not re-enrol: assign a circle.
  Future<void> _changeEnrollmentStatus(
    String studentId, {
    required EnrollmentStatus to,
    required String action,
    required String actorId,
    required String actorRole,
    String? reason,
  }) async {
    final path = '$_collectionPath/$studentId';
    final current = await _ds.getDoc(path);
    if (current == null) throw StateError('Student not found: $studentId');
    final centerId = current['centerId'] as String;

    final archiving = to != EnrollmentStatus.active;
    final open = archiving
        ? await _ds.query('enrollments', where: [
            QueryFilter.equal('centerId', centerId),
            QueryFilter.equal('studentId', studentId),
            QueryFilter.equal('status', 'active'),
          ])
        : <Map<String, dynamic>>[];

    final now = DateTime.now();
    final trimmed = reason?.trim();
    await _ds.commitBatch([
      for (final e in open)
        BatchOp.update('enrollments/${e['id']}', {
          'status': EnrollmentStatus.withdrawn.toJson(),
          'endDate': firestoreConverter.timestampOf(now),
          'changeReason': 'أرشفة الطالب',
          'changedBy': actorId,
          'changedAt': firestoreConverter.timestampOf(now),
          'updatedAt': firestoreConverter.serverTimestamp(),
        }),
      BatchOp.update(path, {
        'enrollmentStatus': to.toJson(),
        if (archiving) 'assignedTeacherIds': <String>[],
        if (archiving) 'currentCircleId': null,
        'updatedBy': actorId,
        'updatedAt': firestoreConverter.serverTimestamp(),
      }),
      BatchOp.set('audit_logs/aud_${now.microsecondsSinceEpoch}_$studentId', {
        'centerId': centerId,
        'actorUserId': actorId,
        'actorRole': actorRole,
        'action': action,
        'entityType': 'student',
        'entityId': studentId,
        'previousValue': {
          'enrollmentStatus': current['enrollmentStatus'],
          if (open.isNotEmpty) 'circleIds': [for (final e in open) e['circleId']],
        },
        'newValue': {'enrollmentStatus': to.toJson()},
        if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
        'createdAt': now.millisecondsSinceEpoch,
      }),
    ]);
  }

  @override
  Stream<List<Student>> watchStudentsByCenter(
    String centerId, {
    EnrollmentStatus? status,
  }) {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      if (status != null) QueryFilter.equal('enrollmentStatus', status.toJson()),
    ];
    return _ds.watchQuery(_collectionPath, where: where).map((docs) => docs
        .map((d) => Student.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList());
  }

  @override
  Future<List<Student>> getStudentsByCenter(String centerId) async {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Student.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  @override
  Future<List<Student>> getStudentsByTeacher(String teacherId,
      {required String centerId}) async {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.arrayContains('assignedTeacherIds', teacherId),
    ];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Student.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
