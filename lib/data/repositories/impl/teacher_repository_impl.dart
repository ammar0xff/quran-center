import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/teacher.dart';
import 'package:quran_center/data/repositories/teacher_repository.dart';

/// Firestore-backed implementation of [TeacherRepository].
///
/// Collection: `teachers/{teacherId}`.
class TeacherRepositoryImpl implements TeacherRepository {
  TeacherRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'teachers';
  static const _timestampKeys = {'createdAt', 'updatedAt'};

  @override
  Future<Teacher?> getTeacher(String teacherId) async {
    final data = await _ds.getDoc('$_collectionPath/$teacherId');
    if (data == null) return null;
    return Teacher.fromJson(teacherId, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createTeacher(Teacher teacher) async {
    final data = firestoreConverter.encodeForWrite(
      teacher.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${teacher.teacherId}', data);
  }

  @override
  Future<void> updateTeacher(Teacher teacher) async {
    final data = firestoreConverter.encodeForWrite(
      teacher.toJson()..removeWhere((k, v) => k == 'teacherId'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${teacher.teacherId}', data);
  }

  @override
  Future<List<Teacher>> getTeachersByCenter(String centerId) async {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Teacher.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
