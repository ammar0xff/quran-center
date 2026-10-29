import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/memorization_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attendance model', () {
    final json = {
      'centerId': 'center-1',
      'sessionId': 'session-1',
      'studentId': 'student-1',
      'status': 'present',
      'recordedBy': 'teacher-1',
      'note': null,
      'correctionMetadata': null,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final attendance = Attendance.fromJson('att-1', json);
      expect(attendance.attendanceId, 'att-1');
      expect(attendance.sessionId, 'session-1');
      expect(attendance.studentId, 'student-1');
      expect(attendance.status, AttendanceStatus.present);
      expect(attendance.recordedBy, 'teacher-1');

      final back = attendance.toJson();
      expect(back['sessionId'], 'session-1');
      expect(back['status'], 'present');
    });

    test('correctionMetadata round-trip', () {
      final withCorrection = Attendance.fromJson('att-1', {
        ...json,
        'status': 'absent',
        'correctionMetadata': {
          'originalStatus': 'present',
          'correctedBy': 'director-1',
          'correctedAt': 1700000000000,
          'reason': 'Teacher error',
        },
      });
      expect(withCorrection.status, AttendanceStatus.absent);
      expect(withCorrection.correctionMetadata, isNotNull);
      expect(withCorrection.correctionMetadata!.originalStatus, AttendanceStatus.present);
      expect(withCorrection.correctionMetadata!.reason, 'Teacher error');

      final back = withCorrection.toJson();
      expect((back['correctionMetadata'] as Map)['reason'], 'Teacher error');
    });
  });

  group('MemorizationRecord model', () {
    final json = {
      'centerId': 'center-1',
      'studentId': 'student-1',
      'teacherId': 'teacher-1',
      'sessionId': 'session-1',
      'circleId': 'circle-1',
      'assessmentType': 'newMemorization',
      'schemaVersion': 1,
      'surah': 2,
      'startAyah': 1,
      'endAyah': 5,
      'criteriaScores': {'accuracy': 4.0, 'tajweed': 3.5},
      'overallAssessment': 'جيد',
      'mistakesCount': 2,
      'mistakeCategory': 'tajweed',
      'mistakeReference': 'آية 3',
      'teacherCorrection': 'راجع المدة',
      'requiresFollowUp': true,
      'strengths': 'حفظ جيد',
      'areasForImprovement': 'التجويد',
      'privateTeacherNote': ' needs more practice',
      'studentVisibleFeedback': ' excellent effort',
      'recommendedNextAssignment': 'سورة البقرة آية 6-10',
      'suggestedNextReviewDate': 1700086400000,
      'assessedAt': 1700000000000,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    };

    test('fromJson/toJson round-trip', () {
      final record = MemorizationRecord.fromJson('rec-1', json);
      expect(record.recordId, 'rec-1');
      expect(record.studentId, 'student-1');
      expect(record.teacherId, 'teacher-1');
      expect(record.assessmentType, AssessmentType.newMemorization);
      expect(record.schemaVersion, 1);
      expect(record.surah, 2);
      expect(record.startAyah, 1);
      expect(record.endAyah, 5);
      expect(record.criteriaScores['accuracy'], 4.0);
      expect(record.mistakesCount, 2);
      expect(record.requiresFollowUp, isTrue);
      expect(record.privateTeacherNote, ' needs more practice');
      expect(record.studentVisibleFeedback, ' excellent effort');

      final back = record.toJson();
      expect(back['surah'], 2);
      expect(back['assessmentType'], 'newMemorization');
      expect(back['criteriaScores']['accuracy'], 4.0);
      expect(back['privateTeacherNote'], ' needs more practice');
      expect(back['studentVisibleFeedback'], ' excellent effort');
    });

    test('private and student-visible fields are stored separately', () {
      final record = MemorizationRecord.fromJson('rec-1', json);
      expect(record.privateTeacherNote, isNotNull);
      expect(record.studentVisibleFeedback, isNotNull);
      expect(record.privateTeacherNote, isNot(record.studentVisibleFeedback));
    });
  });
}
