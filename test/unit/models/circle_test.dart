import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Circle model', () {
    final json = {
      'centerId': 'center-1',
      'name': ' cercleフェーズ 1',
      'description': 'دورة للمبتدئين',
      'educationalLevel': 'مبتدئ',
      'assignedTeacherId': 'teacher-1',
      'maxCapacity': 25,
      'locationOrMode': 'onsite',
      'weeklySchedule': [
        {'dayOfWeek': 1, 'startTime': '08:00', 'endTime': '10:00'},
        {'dayOfWeek': 3, 'startTime': '08:00', 'endTime': '10:00'},
      ],
      'sessionDurationMinutes': 120,
      'status': 'active',
      'adminNotes': null,
      'createdBy': 'director-1',
      'updatedBy': 'director-1',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final circle = Circle.fromJson('circle-1', json);
      expect(circle.circleId, 'circle-1');
      expect(circle.centerId, 'center-1');
      expect(circle.name, ' cercleフェーズ 1');
      expect(circle.maxCapacity, 25);
      expect(circle.status, CircleStatus.active);
      expect(circle.weeklySchedule, hasLength(2));
      expect(circle.weeklySchedule.first.dayOfWeek, 1);
      expect(circle.sessionDurationMinutes, 120);

      final back = circle.toJson();
      expect(back['name'], ' cercleフェーズ 1');
      expect(back['maxCapacity'], 25);
      expect(back['status'], 'active');
      expect((back['weeklySchedule'] as List).length, 2);
    });

    test('copyWith updates only provided fields', () {
      final circle = Circle.fromJson('circle-1', json);
      final updated = circle.copyWith(maxCapacity: 30, status: CircleStatus.archived);
      expect(updated.maxCapacity, 30);
      expect(updated.status, CircleStatus.archived);
      expect(updated.name, ' cercleフェーズ 1'); // unchanged
    });
  });
}
