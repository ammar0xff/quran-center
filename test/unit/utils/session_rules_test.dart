import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/session_rules.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

final _now = DateTime(2026, 11, 10, 9);

Schedule _s(SessionStatus status, {DateTime? date}) => Schedule(
      scheduleId: 's',
      centerId: 'c',
      circleId: 'k',
      teacherId: 't',
      date: date ?? DateTime(2026, 11, 10),
      startTime: '08:00',
      endTime: '09:00',
      locationOrMode: 'onsite',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('checkStart', () {
    test('a scheduled session can start on its day', () {
      expect(checkStart(_s(SessionStatus.scheduled), _now), isNull);
    });
    test('not before or after its day', () {
      expect(checkStart(_s(SessionStatus.scheduled, date: DateTime(2026, 11, 11)), _now),
          SessionBlock.notToday);
      expect(checkStart(_s(SessionStatus.scheduled, date: DateTime(2026, 11, 9)), _now),
          SessionBlock.notToday);
    });
    test('other states cannot be started', () {
      expect(checkStart(_s(SessionStatus.inProgress), _now), SessionBlock.alreadyStarted);
      expect(checkStart(_s(SessionStatus.completed), _now), SessionBlock.completed);
      expect(checkStart(_s(SessionStatus.cancelled), _now), SessionBlock.cancelled);
    });
  });

  group('checkRecord / checkComplete', () {
    test('only an in-progress session accepts attendance or completion', () {
      expect(checkRecord(_s(SessionStatus.inProgress)), isNull);
      expect(checkComplete(_s(SessionStatus.inProgress)), isNull);
      expect(checkRecord(_s(SessionStatus.scheduled)), SessionBlock.notStarted);
      expect(checkRecord(_s(SessionStatus.completed)), SessionBlock.completed);
      expect(checkComplete(_s(SessionStatus.cancelled)), SessionBlock.cancelled);
    });
  });

  test('every block has a distinct Arabic message', () {
    final m = SessionBlock.values.map(sessionBlockMessage).toSet();
    expect(m, hasLength(SessionBlock.values.length));
  });
}
