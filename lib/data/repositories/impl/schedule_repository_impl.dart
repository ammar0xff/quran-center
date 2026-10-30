import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/repositories/schedule_repository.dart';

/// Firestore-backed implementation of [ScheduleRepository].
///
/// Collection: `schedules/{scheduleId}`.
class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._ds);

  final FirestoreDataSource _ds;

  static const _collectionPath = 'schedules';
  static const _timestampKeys = {
    'createdAt',
    'updatedAt',
    'date',
    'cancelledAt',
  };

  @override
  Future<Schedule?> getSchedule(String scheduleId) async {
    final data = await _ds.getDoc('$_collectionPath/$scheduleId');
    if (data == null) return null;
    return Schedule.fromJson(
        scheduleId, firestoreConverter.decodeFromRead(data));
  }

  @override
  Future<void> createSchedule(Schedule schedule) async {
    final data = firestoreConverter.encodeForWrite(
      schedule.toJson(),
      timestampKeys: _timestampKeys,
    );
    await _ds.setDoc('$_collectionPath/${schedule.scheduleId}', data);
  }

  @override
  Future<void> updateSchedule(Schedule schedule) async {
    final data = firestoreConverter.encodeForWrite(
      schedule.toJson()..removeWhere((k, v) => k == 'scheduleId'),
      timestampKeys: _timestampKeys,
    );
    await _ds.updateDoc('$_collectionPath/${schedule.scheduleId}', data);
  }

  @override
  Future<void> cancelSchedule(
    String scheduleId, {
    required String actorId,
    required String reason,
  }) async {
    await _ds.updateDoc('$_collectionPath/$scheduleId', {
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledBy': actorId,
      'cancelledAt': firestoreConverter.serverTimestamp(),
      'updatedBy': actorId,
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  @override
  Future<List<Schedule>> getSchedulesByCenter(
    String centerId, {
    String? circleId,
    String? teacherId,
    DateTime? date,
  }) async {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    if (circleId != null) {
      where.add(QueryFilter.equal('circleId', circleId));
    }
    if (teacherId != null) {
      where.add(QueryFilter.equal('teacherId', teacherId));
    }
    final docs = await _ds.query(_collectionPath, where: where);
    return docs
        .map((d) => Schedule.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .where((s) => date == null || s.date.isSameDate(date))
        .toList();
  }

  @override
  Stream<List<Schedule>> watchSchedulesByCenter(
    String centerId, {
    String? circleId,
    String? teacherId,
    DateTime? date,
  }) async* {
    final where = <QueryFilter>[QueryFilter.equal('centerId', centerId)];
    if (circleId != null) {
      where.add(QueryFilter.equal('circleId', circleId));
    }
    if (teacherId != null) {
      where.add(QueryFilter.equal('teacherId', teacherId));
    }
    yield* _ds.watchQuery(_collectionPath, where: where).map((docs) => docs
        .map((d) => Schedule.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .where((s) => date == null || s.date.isSameDate(date))
        .toList());
  }
}
