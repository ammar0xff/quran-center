import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/repositories/enrollment_repository.dart';

/// Firestore-backed implementation of [EnrollmentRepository].
///
/// Collection: `enrollments/{enrollmentId}`.
class EnrollmentRepositoryImpl implements EnrollmentRepository {
  EnrollmentRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'enrollments';
  static const _timestampKeys = {
    'createdAt',
    'updatedAt',
    'startDate',
    'endDate',
    'changedAt',
  };

  @override
  Future<Enrollment?> getEnrollment(String enrollmentId) async {
    final data = await _ds.getDoc('$_collectionPath/$enrollmentId');
    if (data == null) return null;
    return Enrollment.fromJson(enrollmentId, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createEnrollment(Enrollment enrollment) async {
    final data = firestoreConverter.encodeForWrite(
      enrollment.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${enrollment.enrollmentId}', data);
  }

  @override
  Future<void> updateEnrollment(Enrollment enrollment) async {
    final data = firestoreConverter.encodeForWrite(
      enrollment.toJson()..removeWhere((k, v) => k == 'enrollmentId'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${enrollment.enrollmentId}', data);
  }

  @override
  Future<List<Enrollment>> getActiveEnrollmentsForStudent(String studentId,
      {required String centerId}) async {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
      QueryFilter.equal('status', 'active'),
    ];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Enrollment.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  @override
  Future<List<Enrollment>> getActiveEnrollmentsForCircle(String circleId,
      {required String centerId}) async {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('circleId', circleId),
      QueryFilter.equal('status', 'active'),
    ];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Enrollment.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  @override
  Future<List<Enrollment>> getHistoryForStudent(String studentId,
      {required String centerId}) async {
    final docs = await _ds.query(_collectionPath, where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ]);
    final list = docs
        .map((d) => Enrollment.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  @override
  Stream<List<Enrollment>> watchEnrollmentsForStudent(String studentId,
      {required String centerId}) {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('studentId', studentId),
    ];
    return _ds.watchQuery(_collectionPath, where: where).map((docs) => docs
        .map((d) => Enrollment.fromJson(d['id'] ?? '',
            firestoreConverter.decodeFromRead(d)))
        .toList());
  }
}
