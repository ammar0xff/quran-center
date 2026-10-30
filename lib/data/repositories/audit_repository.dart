import 'package:quran_center/data/models/audit_log.dart';

/// Read access to the audit trail.
///
/// Audit entries are written by the repositories that perform the audited
/// operation (inside the same atomic batch), never directly by UI code.
abstract class AuditRepository {
  /// Audit entries for one entity, newest first.
  Future<List<AuditLog>> getForEntity(String entityType, String entityId,
      {required String centerId});
}
