import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/audit_log.dart';
import 'package:quran_center/data/repositories/audit_repository.dart';

/// Firestore-backed [AuditRepository]. Collection: `audit_logs/{auditId}`.
class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const collectionPath = 'audit_logs';

  @override
  Future<List<AuditLog>> getForEntity(String entityType, String entityId) async {
    final docs = await _ds.query(collectionPath, where: [
      QueryFilter.equal('entityType', entityType),
      QueryFilter.equal('entityId', entityId),
    ]);
    final logs = docs
        .map((d) => AuditLog.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }
}
