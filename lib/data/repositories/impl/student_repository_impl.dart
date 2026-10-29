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
    String? reason,
  }) async {
    await _ds.updateDoc('$_collectionPath/$studentId', {
      'enrollmentStatus': EnrollmentStatus.archived.toJson(),
      'updatedBy': actorId,
      'updatedAt': firestoreConverter.serverTimestamp(),
      if (reason != null) 'adminNotes': reason,
    });
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
  Future<List<Student>> getStudentsByTeacher(String teacherId) async {
    final where = <QueryFilter>[
      QueryFilter.arrayContains('assignedTeacherIds', teacherId)
    ];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Student.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
