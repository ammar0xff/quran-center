import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/repositories/user_repository.dart';

/// Firestore-backed implementation of [UserRepository].
///
/// Collection: `users/{uid}`.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'users';
  static const _timestampKeys = {'createdAt', 'updatedAt', 'lastSignInAt'};

  @override
  Future<User?> getUser(String uid) async {
    final data = await _ds.getDoc('$_collectionPath/$uid');
    if (data == null) return null;
    return User.fromJson(uid, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createUser(User user) async {
    final data = firestoreConverter.encodeForWrite(
      user.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${user.uid}', data);
  }

  @override
  Future<void> updateUser(User user) async {
    final data = firestoreConverter.encodeForWrite(
      user.toJson()..removeWhere((k, v) => k == 'uid'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${user.uid}', data);
  }

  @override
  Stream<List<User>> watchUsersByCenter(String centerId) {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('status', 'active'),
    ];
    return _ds.watchQuery(_collectionPath, where: where).map((docs) => docs
        .map((d) =>
            User.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList());
  }

  @override
  Future<List<User>> getUsersByCenter(String centerId) async {
    final where = <QueryFilter>[
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('status', 'active'),
    ];
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) =>
            User.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  @override
  Future<List<User>> getAllUsersByCenter(String centerId) async {
    final docs = await _ds.query(_collectionPath,
        where: [QueryFilter.equal('centerId', centerId)]);
    return docs
        .map((d) =>
            User.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
