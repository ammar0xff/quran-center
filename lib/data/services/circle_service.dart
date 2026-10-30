import 'dart:convert';

import 'package:quran_center/core/utils/circle_validation.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

/// A circle change that cannot proceed. [message] is user-facing Arabic.
class CircleException implements Exception {
  CircleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Edits and archives circles while keeping everything that depends on the
/// circle consistent.
///
/// Changing a circle's teacher is one atomic batch that also moves the
/// teacher onto the circle's active enrolments, onto each enrolled student's
/// `assignedTeacherIds` (the Security Rules let a teacher read exactly those
/// students) and onto the circle's upcoming scheduled sessions. Sessions that
/// already started or finished keep the teacher who actually ran them.
///
/// A Firestore batch holds at most 500 writes. A normal circle changes teacher
/// in ONE atomic batch; a very large one is applied in several batches, circle
/// last, and is safe to repeat if one of them fails.
class CircleService {
  CircleService(this._ds, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  static const maxBatchOps = 450;

  Future<Map<String, dynamic>> _circle(String centerId, String circleId) async {
    final raw = await _ds.getDoc('circles/$circleId');
    // Other-center circles look the same as missing ones.
    if (raw == null || raw['centerId'] != centerId) {
      throw CircleException('لم يتم العثور على الحلقة.');
    }
    return raw;
  }

  Future<List<Map<String, dynamic>>> _activeEnrollments(
          String centerId, String circleId) =>
      _ds.query('enrollments', where: [
        QueryFilter.equal('centerId', centerId),
        QueryFilter.equal('circleId', circleId),
        QueryFilter.equal('status', 'active'),
      ]);

  /// Saves the circle's descriptive fields and teacher. Returns false when
  /// nothing changed (nothing is written, no audit entry).
  Future<bool> update(
    String circleId, {
    required String centerId,
    required String actorId,
    required String actorRole,
    required String name,
    required String educationalLevel,
    String? description,
    required int maxCapacity,
    required int sessionDurationMinutes,
    required String locationOrMode,
    String? teacherId,

    /// null leaves the weekly schedule as it is; a list replaces it.
    List<CircleWeeklySchedule>? weeklySchedule,
  }) async {
    final current = await _circle(centerId, circleId);
    if (current['status'] != 'active') {
      throw CircleException('لا يمكن تعديل حلقة مؤرشفة.');
    }

    final errors = validateCircleForm(
      name: name,
      capacity: '$maxCapacity',
      duration: '$sessionDurationMinutes',
      scheduleDays: const {},
      start: '',
      end: '',
    );
    if (errors.hasErrors) {
      throw CircleException(errors.name ??
          errors.capacity ??
          errors.duration ??
          'بيانات غير صالحة.');
    }

    if (weeklySchedule != null) {
      final problem = weeklyScheduleError({
        for (final w in weeklySchedule) w.dayOfWeek: (w.startTime, w.endTime)
      });
      if (problem != null) throw CircleException(problem);
      if (weeklySchedule.map((w) => w.dayOfWeek).toSet().length !=
          weeklySchedule.length) {
        throw CircleException('يوم مكرر في الجدول.');
      }
    }

    if (teacherId != null) {
      final teacher = await _ds.getDoc('teachers/$teacherId');
      if (teacher == null || teacher['centerId'] != centerId) {
        throw CircleException('لم يتم العثور على المعلم.');
      }
      if (teacher['status'] != 'active') {
        throw CircleException('لا يمكن تعيين معلم غير نشط.');
      }
    }

    final enrolled = await _activeEnrollments(centerId, circleId);
    if (maxCapacity < enrolled.length) {
      throw CircleException(
          'السعة أقل من عدد الطلاب الحاليين (${enrolled.length}). انقل بعض الطلاب أولًا.');
    }

    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final wanted = <String, dynamic>{
      'name': name.trim(),
      'educationalLevel': educationalLevel.trim(),
      'description': clean(description),
      'maxCapacity': maxCapacity,
      'sessionDurationMinutes': sessionDurationMinutes,
      'locationOrMode': locationOrMode,
      'assignedTeacherId': teacherId,
    };
    if (weeklySchedule != null) {
      final sorted = [...weeklySchedule]
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
      wanted['weeklySchedule'] = [for (final w in sorted) w.toJson()];
    }
    final previous = <String, dynamic>{};
    final next = <String, dynamic>{};
    wanted.forEach((key, value) {
      final same = value is List
          ? jsonEncode(_normalized(current[key])) ==
              jsonEncode(_normalized(value))
          : current[key] == value;
      if (!same) {
        previous[key] = current[key];
        next[key] = value;
      }
    });
    if (next.isEmpty) return false;

    final teacherChanged = next.containsKey('assignedTeacherId');
    final ops = <BatchOp>[];

    if (teacherChanged) {
      final today = _now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      final upcoming = (await _ds.query('schedules', where: [
        QueryFilter.equal('centerId', centerId),
        QueryFilter.equal('circleId', circleId),
        QueryFilter.equal('status', 'scheduled'),
      ]))
          .where((d) {
        final s = Schedule.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d));
        return !s.date.isBefore(startOfToday);
      }).toList();

      final now = firestoreConverter.serverTimestamp();
      for (final e in enrolled) {
        ops.add(BatchOp.update('enrollments/${e['id']}', {
          'teacherId': teacherId,
          'changedBy': actorId,
          'updatedAt': now,
        }));
        ops.add(BatchOp.update('students/${e['studentId']}', {
          'assignedTeacherIds': teacherId == null ? <String>[] : [teacherId],
          'updatedBy': actorId,
          'updatedAt': now,
        }));
      }
      for (final s in upcoming) {
        ops.add(BatchOp.update('schedules/${s['id']}', {
          'teacherId': teacherId,
          'updatedAt': now,
        }));
      }
    }

    final when = _now();
    final tail = <BatchOp>[];
    tail.add(BatchOp.update('circles/$circleId', {
      ...next,
      'updatedBy': actorId,
      'updatedAt': firestoreConverter.serverTimestamp(),
    }));
    tail.add(
        BatchOp.set('audit_logs/aud_${when.microsecondsSinceEpoch}_$circleId', {
      'centerId': centerId,
      'actorUserId': actorId,
      'actorRole': actorRole,
      'action': teacherChanged ? 'change_circle_teacher' : 'update_circle',
      'entityType': 'circle',
      'entityId': circleId,
      'previousValue': previous,
      'newValue': next,
      'createdAt': when.millisecondsSinceEpoch,
    }));
    if (ops.length + tail.length <= maxBatchOps) {
      await _ds.commitBatch([...ops, ...tail]); // the normal case: fully atomic
    } else {
      // Too big for one Firestore batch. The dependants move first, and the
      // circle (with its audit entry) changes last, so a failure part-way
      // leaves the circle on its old teacher and the same save can simply be
      // repeated: every step writes the same values again.
      for (var i = 0; i < ops.length; i += maxBatchOps) {
        await _ds.commitBatch(
            ops.sublist(i, (i + maxBatchOps).clamp(0, ops.length)));
      }
      await _ds.commitBatch(tail);
    }
    return true;
  }

  /// Schedules sorted by weekday so equal schedules compare equal.
  List<dynamic> _normalized(dynamic list) {
    final l = [...((list as List?) ?? const [])];
    l.sort((a, b) => (a['dayOfWeek'] as int).compareTo(b['dayOfWeek'] as int));
    return [
      for (final w in l)
        {
          'dayOfWeek': w['dayOfWeek'],
          'startTime': w['startTime'],
          'endTime': w['endTime']
        }
    ];
  }

  /// Archives a circle. Refused while students are still enrolled, so no
  /// student is left in a circle that no longer runs; transfer them first.
  Future<void> archive(
    String circleId, {
    required String centerId,
    required String actorId,
    required String actorRole,
  }) async {
    final current = await _circle(centerId, circleId);
    if (current['status'] == 'archived') {
      throw CircleException('الحلقة مؤرشفة بالفعل.');
    }
    final enrolled = await _activeEnrollments(centerId, circleId);
    if (enrolled.isNotEmpty) {
      throw CircleException(
          'في الحلقة ${enrolled.length} طالبًا. انقلهم إلى حلقة أخرى قبل الأرشفة.');
    }
    final when = _now();
    await _ds.commitBatch([
      BatchOp.update('circles/$circleId', {
        'status': CircleStatus.archived.toJson(),
        'updatedBy': actorId,
        'updatedAt': firestoreConverter.serverTimestamp(),
      }),
      BatchOp.set('audit_logs/aud_${when.microsecondsSinceEpoch}_$circleId', {
        'centerId': centerId,
        'actorUserId': actorId,
        'actorRole': actorRole,
        'action': 'archive_circle',
        'entityType': 'circle',
        'entityId': circleId,
        'previousValue': {'status': 'active'},
        'newValue': {'status': 'archived'},
        'createdAt': when.millisecondsSinceEpoch,
      }),
    ]);
  }
}
