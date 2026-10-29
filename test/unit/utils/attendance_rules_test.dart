import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/attendance_rules.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';

Attendance _a(String student, AttendanceStatus status) => Attendance(
      attendanceId: 'x_$student',
      centerId: 'center-1',
      sessionId: 'x',
      studentId: student,
      status: status,
      recordedBy: 't1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('attendanceDocId is deterministic per session+student', () {
    expect(attendanceDocId('s1', 'a'), attendanceDocId('s1', 'a'));
    expect(attendanceDocId('s1', 'a'), isNot(attendanceDocId('s1', 'b')));
    expect(attendanceDocId('s1', 'a'), isNot(attendanceDocId('s2', 'a')));
  });

  group('AttendanceSummary', () {
    test('counts each status', () {
      final s = AttendanceSummary.from([
        _a('1', AttendanceStatus.present),
        _a('2', AttendanceStatus.present),
        _a('3', AttendanceStatus.absent),
        _a('4', AttendanceStatus.late),
        _a('5', AttendanceStatus.excused),
      ]);
      expect(s.present, 2);
      expect(s.absent, 1);
      expect(s.late, 1);
      expect(s.excused, 1);
      expect(s.recorded, 5);
    });

    test('rate counts late as attended and excludes excused', () {
      // present 2 + late 1 attended; absent 1 -> 3/4. Excused ignored.
      final s = AttendanceSummary.from([
        _a('1', AttendanceStatus.present),
        _a('2', AttendanceStatus.present),
        _a('3', AttendanceStatus.late),
        _a('4', AttendanceStatus.absent),
        _a('5', AttendanceStatus.excused),
      ]);
      expect(s.rate, closeTo(0.75, 1e-9));
    });

    test('rate is null when there is nothing to base it on', () {
      expect(AttendanceSummary.from([]).rate, isNull);
      expect(
        AttendanceSummary.from([_a('1', AttendanceStatus.excused)]).rate,
        isNull,
      );
    });

    test('missing records are not counted as absences', () {
      final s = AttendanceSummary.from(
        [_a('1', AttendanceStatus.present)],
        expectedCount: 4,
      );
      expect(s.missing, 3);
      expect(s.absent, 0);
      expect(s.rate, 1.0);
    });

    test('missing never goes negative', () {
      final s = AttendanceSummary.from(
        [_a('1', AttendanceStatus.present), _a('2', AttendanceStatus.present)],
        expectedCount: 1,
      );
      expect(s.missing, 0);
    });
  });

  group('validateCorrection', () {
    test('requires a non-blank reason', () {
      expect(
        validateCorrection(
          current: AttendanceStatus.absent,
          requested: AttendanceStatus.present,
          reason: '   ',
        ),
        CorrectionError.reasonRequired,
      );
    });

    test('rejects a no-op change', () {
      expect(
        validateCorrection(
          current: AttendanceStatus.present,
          requested: AttendanceStatus.present,
          reason: 'typo',
        ),
        CorrectionError.sameStatus,
      );
    });

    test('accepts a real change with a reason', () {
      expect(
        validateCorrection(
          current: AttendanceStatus.absent,
          requested: AttendanceStatus.excused,
          reason: 'medical note received',
        ),
        isNull,
      );
    });
  });
}
