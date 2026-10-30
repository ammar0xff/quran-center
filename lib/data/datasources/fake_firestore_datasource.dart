import 'dart:async';

import 'package:quran_center/data/datasources/firestore_datasource.dart';

/// In-memory implementation of [FirestoreDataSource] for unit tests.
///
/// Documents are stored by full path (e.g. `students/student-1`). Query results
/// include the document `id` merged into each map, mirroring
/// [FirebaseFirestoreDataSource].
class FakeFirestoreDataSource implements FirestoreDataSource {
  final _docs = <String, Map<String, dynamic>>{}; // full path -> data (no id)

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final data = _docs[path];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  Future<void> setDoc(String path, Map<String, dynamic> data,
      {bool merge = false}) async {
    if (merge && _docs.containsKey(path)) {
      _docs[path] = {..._docs[path]!, ...data};
    } else {
      _docs[path] = Map<String, dynamic>.from(data);
    }
  }

  @override
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    if (!_docs.containsKey(path)) {
      throw StateError('Document not found: $path');
    }
    _docs[path] = {..._docs[path]!, ...data};
  }

  @override
  Future<void> commitBatch(List<BatchOp> ops) async {
    // Validate everything first so a failing op leaves no partial writes.
    for (final op in ops) {
      if (op.isUpdate && !_docs.containsKey(op.path)) {
        throw StateError('Document not found: ${op.path}');
      }
    }
    for (final op in ops) {
      if (op.isUpdate) {
        _docs[op.path] = {..._docs[op.path]!, ...op.data};
      } else {
        _docs[op.path] = Map<String, dynamic>.from(op.data);
      }
    }
  }

  Future<void> _txTail = Future.value();

  /// Transactions run one at a time, each seeing the previous one's writes, so
  /// concurrent callers behave as they would after Firestore's retry.
  @override
  Future<T> runTransaction<T>(Future<T> Function(TxContext tx) body) {
    final previous = _txTail;
    final done = Completer<void>();
    _txTail = done.future;
    return previous.then((_) async {
      try {
        final ctx = _FakeTx(this);
        final result = await body(ctx);
        await commitBatch(ctx.ops);
        return result;
      } finally {
        done.complete();
      }
    });
  }

  List<Map<String, dynamic>> _docsInCollection(String collection) {
    final prefix = '$collection/';
    return _docs.entries
        .where((e) => e.key.startsWith(prefix))
        .where((e) {
          final rest = e.key.substring(prefix.length);
          return !rest.contains('/'); // direct children only
        })
        .map((e) => {...e.value, 'id': e.key.substring(prefix.length)})
        .toList();
  }

  bool _matches(Map<String, dynamic> doc, QueryFilter f) {
    final value = doc[f.field];
    switch (f.type) {
      case QueryFilterType.equal:
        return value == f.value;
      case QueryFilterType.arrayContains:
        final list = value as List<dynamic>?;
        return list != null && list.contains(f.value);
    }
  }

  List<Map<String, dynamic>> _applyWhere(
      List<Map<String, dynamic>> docs, List<QueryFilter> where) {
    var result = docs;
    for (final f in where) {
      result = result.where((d) => _matches(d, f)).toList();
    }
    return result;
  }

  int _compare(dynamic a, dynamic b) {
    if (a is Comparable && b is Comparable && a.runtimeType == b.runtimeType) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    var result = _applyWhere(_docsInCollection(collection), where);
    if (orderBy != null) {
      result.sort((a, b) => _compare(a[orderBy], b[orderBy]));
      if (descending) result = result.reversed.toList();
    }
    if (limit != null) result = result.take(limit).toList();
    return result;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchQuery(
    String collection, {
    required List<QueryFilter> where,
    String? orderBy,
    bool descending = false,
  }) async* {
    yield await query(collection,
        where: where, orderBy: orderBy, descending: descending);
  }
}

class _FakeTx implements TxContext {
  _FakeTx(this._store);
  final FakeFirestoreDataSource _store;
  final ops = <BatchOp>[];

  @override
  Future<Map<String, dynamic>?> get(String path) => _store.getDoc(path);

  @override
  void set(String path, Map<String, dynamic> data) => ops.add(BatchOp.set(path, data));

  @override
  void update(String path, Map<String, dynamic> data) => ops.add(BatchOp.update(path, data));
}
