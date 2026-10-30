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

/// One write inside an atomic batch.
class BatchOp {
  const BatchOp.set(this.path, this.data) : isUpdate = false;
  const BatchOp.update(this.path, this.data) : isUpdate = true;

  final String path;
  final Map<String, dynamic> data;

  /// true = update an existing document, false = create/overwrite.
  final bool isUpdate;
}

/// Reads and buffered writes inside a transaction. All reads must come before
/// the writes are applied (writes are applied together when the body returns).
abstract class TxContext {
  Future<Map<String, dynamic>?> get(String path);
  void set(String path, Map<String, dynamic> data);
  void update(String path, Map<String, dynamic> data);
}

/// Abstract Firestore data source.
///
/// Keeps repository implementations free of direct Firebase SDK calls so they
/// can be tested with an in-memory fake (no mockito argument-matchers needed).
abstract class FirestoreDataSource {
  /// Read a single document.
  Future<Map<String, dynamic>?> getDoc(String path);

  /// Create/overwrite a document.
  Future<void> setDoc(String path, Map<String, dynamic> data,
      {bool merge = false});

  /// Update fields on an existing document.
  Future<void> updateDoc(String path, Map<String, dynamic> data);

  /// Applies all [ops] atomically: either every write lands or none do.
  Future<void> commitBatch(List<BatchOp> ops);

  /// Runs [body] as a transaction: the documents it reads are re-checked at
  /// commit, and the whole body is retried if any of them changed meanwhile.
  /// Use it for read-then-write rules such as "never exceed the capacity".
  Future<T> runTransaction<T>(Future<T> Function(TxContext tx) body);

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

  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    final batch = _firestore.batch();
    for (final op in ops) {
      final ref = _firestore.doc(op.path);
      if (op.isUpdate) {
        batch.update(ref, op.data);
      } else {
        batch.set(ref, op.data);
      }
    }
    await batch.commit();
  }

  @override
  Future<T> runTransaction<T>(Future<T> Function(TxContext tx) body) {
    return _firestore.runTransaction((t) async {
      final ctx = _FirebaseTx(_firestore, t);
      final result = await body(ctx);
      ctx.flush();
      return result;
    });
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

class _FirebaseTx implements TxContext {
  _FirebaseTx(this._firestore, this._tx);

  final FirebaseFirestore _firestore;
  final Transaction _tx;
  final _ops = <BatchOp>[];

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snap = await _tx.get(_firestore.doc(path));
    return snap.data();
  }

  @override
  void set(String path, Map<String, dynamic> data) =>
      _ops.add(BatchOp.set(path, data));

  @override
  void update(String path, Map<String, dynamic> data) =>
      _ops.add(BatchOp.update(path, data));

  void flush() {
    for (final op in _ops) {
      final ref = _firestore.doc(op.path);
      if (op.isUpdate) {
        _tx.update(ref, op.data);
      } else {
        _tx.set(ref, op.data);
      }
    }
  }
}
