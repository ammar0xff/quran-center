import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/schedule_conflicts.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

Schedule _s({
  String id = 's1',
  String circle = 'c1',
  String teacher = 't1',
  DateTime? date,
  String start = '08:00',
  String end = '10:00',
  SessionStatus status = SessionStatus.scheduled,
}) {
  return Schedule(
    scheduleId: id,
    centerId: 'center-1',
    circleId: circle,
    teacherId: teacher,
    date: date ?? DateTime(2026, 11, 2),
    startTime: start,
    endTime: end,
    locationOrMode: 'onsite',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('isValidTimeRange', () {
    test('accepts start before end', () {
      expect(isValidTimeRange('08:00', '09:30'), isTrue);
    });
    test('rejects equal or reversed times', () {
      expect(isValidTimeRange('09:00', '09:00'), isFalse);
      expect(isValidTimeRange('10:00', '09:00'), isFalse);
    });
    test('rejects malformed values', () {
      expect(isValidTimeRange('8', '9'), isFalse);
      expect(isValidTimeRange('25:00', '26:00'), isFalse);
      expect(isValidTimeRange('08:61', '09:00'), isFalse);
    });
  });

  group('findScheduleConflicts', () {
    test('detects teacher conflict on overlapping time', () {
      final candidate = _s(id: 'new', circle: 'c2', start: '09:00', end: '11:00');
      final result = findScheduleConflicts(candidate, [_s()]);
      expect(result, hasLength(1));
      expect(result.first.type, ConflictType.teacher);
    });

    test('detects circle conflict with a different teacher', () {
      final candidate = _s(id: 'new', teacher: 't2', start: '09:00', end: '11:00');
      final result = findScheduleConflicts(candidate, [_s()]);
      expect(result, hasLength(1));
      expect(result.first.type, ConflictType.circle);
    });

    test('reports both when teacher and circle both clash', () {
      final candidate = _s(id: 'new', start: '09:00', end: '11:00');
      final result = findScheduleConflicts(candidate, [_s()]);
      expect(result.map((c) => c.type),
          containsAll([ConflictType.teacher, ConflictType.circle]));
    });

    test('touching boundaries are not a conflict', () {
      final candidate = _s(id: 'new', start: '10:00', end: '11:00');
      expect(findScheduleConflicts(candidate, [_s()]), isEmpty);
    });

    test('different date is not a conflict', () {
      final candidate = _s(id: 'new', date: DateTime(2026, 11, 3));
      expect(findScheduleConflicts(candidate, [_s()]), isEmpty);
    });

    test('cancelled sessions are ignored', () {
      final candidate = _s(id: 'new');
      final cancelled = _s(status: SessionStatus.cancelled);
      expect(findScheduleConflicts(candidate, [cancelled]), isEmpty);
    });

    test('editing a session does not conflict with itself', () {
      final existing = _s(id: 'same');
      final edited = _s(id: 'same', start: '08:30', end: '10:30');
      expect(findScheduleConflicts(edited, [existing]), isEmpty);
    });

    test('unrelated teacher and circle at same time is fine', () {
      final candidate = _s(id: 'new', circle: 'c9', teacher: 't9');
      expect(findScheduleConflicts(candidate, [_s()]), isEmpty);
    });
  });
}
