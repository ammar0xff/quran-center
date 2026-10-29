import 'package:cloud_firestore/cloud_firestore.dart';

/// A filter applied to a Firestore query.
class QueryFilter {
  final String field;
  final dynamic value;
  final QueryFilterType type;

  QueryFilter.equal(this.field, this.value) : type = QueryFilterType.equal;
  QueryFilter.arrayContains(this.field, this.value)
      : type = QueryFilterType.arrayContains;
}

/// Type of query filter.
enum QueryFilterType { equal, arrayContains }

/// Abstract Firestore data source.
///
/// Keeps repository implementations free of direct Firebase SDK calls so they
/// can be tested with an in-memory fake (no mockito argument-matchers needed).
abstract class FirestoreDataSource {
  /// Read a single document.
  Future<Map<String, dynamic>?> getDoc(String path);

  /// Create/overwrite a document.
  Future<void> setDoc(String path, Map<String, dynamic> data, {bool merge = false});

  /// Update fields on an existing document.
  Future<void> updateDoc(String path, Map<String, dynamic> data);

  /// Query a collection (one-page fetch).
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  /// Watch a collection as a real-time stream.
  Stream<List<Map<String, dynamic>>> watchQuery(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
  });
}

/// Firebase-backed implementation of [FirestoreDataSource].
class FirebaseFirestoreDataSource implements FirestoreDataSource {
  FirebaseFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final doc = await _firestore.doc(path).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data,
      {bool merge = false}) async {
    await _firestore.doc(path).set(data, SetOptions(merge: merge));
  }

  @override
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    await _firestore.doc(path).update(data);
  }

  Query<Map<String, dynamic>> _applyFilters(
      Query<Map<String, dynamic>> query, List<QueryFilter> where) {
    for (final f in where) {
      switch (f.type) {
        case QueryFilterType.equal:
          query = query.where(f.field, isEqualTo: f.value);
        case QueryFilterType.arrayContains:
          query = query.where(f.field, arrayContains: f.value);
      }
    }
    return query;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> q = _firestore.collection(collection);
    q = _applyFilters(q, where);
    if (orderBy != null) {
      q = q.orderBy(orderBy, descending: descending);
    }
    if (limit != null) {
      q = q.limit(limit);
    }
    final snap = await q.get();
    return snap.docs.map((d) {
      final data = d.data();
      return {...data, 'id': d.id};
    }).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchQuery(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
  }) {
    Query<Map<String, dynamic>> q = _firestore.collection(collection);
    q = _applyFilters(q, where);
    if (orderBy != null) {
      q = q.orderBy(orderBy, descending: descending);
    }
    return q.snapshots().map((snap) => snap.docs.map((d) {
      final data = d.data();
      return {...data, 'id': d.id};
    }).toList());
  }
}
