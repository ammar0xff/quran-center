import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/repositories/circle_repository.dart';

/// Firestore-backed implementation of [CircleRepository].
///
/// Collection: `circles/{circleId}`.
class CircleRepositoryImpl implements CircleRepository {
  CircleRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'circles';
  static const _timestampKeys = {'createdAt', 'updatedAt'};

  @override
  Future<Circle?> getCircle(String circleId) async {
    final data = await _ds.getDoc('$_collectionPath/$circleId');
    if (data == null) return null;
    return Circle.fromJson(circleId, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createCircle(Circle circle) async {
    final data = firestoreConverter.encodeForWrite(
      circle.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${circle.circleId}', data);
  }

  @override
  Future<void> updateCircle(Circle circle) async {
    final data = firestoreConverter.encodeForWrite(
      circle.toJson()..removeWhere((k, v) => k == 'circleId'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${circle.circleId}', data);
  }

  @override
  Future<void> archiveCircle(
    String circleId, {
    required String actorId,
    String? reason,
  }) async {
    await _ds.updateDoc('$_collectionPath/$circleId', {
      'status': 'archived',
      'updatedBy': actorId,
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  @override
  Stream<List<Circle>> watchCirclesByCenter(String centerId) {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    return _ds.watchQuery(_collectionPath, where: where).map((docs) => docs
        .map((d) => Circle.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList());
  }

  @override
  Future<List<Circle>> getCirclesByCenter(String centerId) async {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Circle.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  @override
  Future<List<Circle>> getCirclesByTeacher(String teacherId) async {
    final where = <QueryFilter>[QueryFilter.equal('assignedTeacherId', teacherId)];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Circle.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
