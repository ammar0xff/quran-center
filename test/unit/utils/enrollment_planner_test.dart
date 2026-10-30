import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/enrollment_planner.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

final _t0 = DateTime(2026, 1, 1);

Student _student({EnrollmentStatus status = EnrollmentStatus.active}) => Student(
      studentId: 's1',
      centerId: 'c',
      fullName: 'طالب',
      enrollmentStatus: status,
      accountMode: AccountMode.none,
      educationalLevel: 'x',
      createdAt: _t0,
      updatedAt: _t0,
    );

Circle _circle({
  String id = 'circle1',
  int capacity = 3,
  CircleStatus status = CircleStatus.active,
  String? teacher = 'tA',
}) =>
    Circle(
      circleId: id,
      centerId: 'c',
      name: id,
      educationalLevel: 'x',
      assignedTeacherId: teacher,
      maxCapacity: capacity,
      locationOrMode: 'onsite',
      weeklySchedule: const [],
      sessionDurationMinutes: 60,
      status: status,
      createdAt: _t0,
      updatedAt: _t0,
    );

Enrollment _enr(String id, String circle, {EnrollmentStatus status = EnrollmentStatus.active}) =>
    Enrollment(
      enrollmentId: id,
      centerId: 'c',
      studentId: 's1',
      circleId: circle,
      startDate: _t0,
      status: status,
      createdAt: _t0,
      updatedAt: _t0,
    );

void main() {
  test('a first assignment succeeds and adopts the circle\'s teacher', () {
    final r = planAssignment(
        student: _student(),
        circle: _circle(),
        studentActiveEnrollments: [],
        circleActiveCount: 0);
    expect(r.error, isNull);
    expect(r.plan!.toTransfer, isEmpty);
    expect(r.plan!.teacherId, 'tA');
    expect(r.plan!.studentTeacherIds, ['tA']);
  });

  test('a circle without a teacher leaves the student without an assigned teacher', () {
    final r = planAssignment(
        student: _student(),
        circle: _circle(teacher: null),
        studentActiveEnrollments: [],
        circleActiveCount: 0);
    expect(r.plan!.teacherId, isNull);
    expect(r.plan!.studentTeacherIds, isEmpty);
  });

  test('moving to another circle is a transfer of the current enrolment', () {
    final current = _enr('e-old', 'oldCircle');
    final r = planAssignment(
        student: _student(),
        circle: _circle(),
        studentActiveEnrollments: [current],
        circleActiveCount: 1);
    expect(r.error, isNull);
    expect(r.plan!.toTransfer.map((e) => e.enrollmentId), ['e-old']);
  });

  test('already in the same circle is rejected as a duplicate', () {
    final r = planAssignment(
        student: _student(),
        circle: _circle(),
        studentActiveEnrollments: [_enr('e', 'circle1')],
        circleActiveCount: 1);
    expect(r.error, AssignmentError.alreadyInCircle);
  });

  test('duplicate is reported even when the circle is also full', () {
    final r = planAssignment(
        student: _student(),
        circle: _circle(capacity: 1),
        studentActiveEnrollments: [_enr('e', 'circle1')],
        circleActiveCount: 1);
    expect(r.error, AssignmentError.alreadyInCircle);
  });

  test('a full circle rejects; one place left accepts', () {
    expect(
        planAssignment(
                student: _student(),
                circle: _circle(capacity: 3),
                studentActiveEnrollments: [],
                circleActiveCount: 3)
            .error,
        AssignmentError.circleFull);
    expect(
        planAssignment(
                student: _student(),
                circle: _circle(capacity: 3),
                studentActiveEnrollments: [],
                circleActiveCount: 2)
            .error,
        isNull);
  });

  test('archived circles and inactive students are rejected', () {
    expect(
        planAssignment(
                student: _student(),
                circle: _circle(status: CircleStatus.archived),
                studentActiveEnrollments: [],
                circleActiveCount: 0)
            .error,
        AssignmentError.circleNotActive);
    for (final s in [
      EnrollmentStatus.archived,
      EnrollmentStatus.withdrawn,
      EnrollmentStatus.completed,
    ]) {
      expect(
          planAssignment(
                  student: _student(status: s),
                  circle: _circle(),
                  studentActiveEnrollments: [],
                  circleActiveCount: 0)
              .error,
          AssignmentError.studentNotActive,
          reason: '$s');
    }
  });

  test('already-closed enrolments are not transferred again', () {
    final r = planAssignment(
        student: _student(),
        circle: _circle(),
        studentActiveEnrollments: [
          _enr('done', 'old', status: EnrollmentStatus.transferred),
          _enr('live', 'other'),
        ],
        circleActiveCount: 0);
    expect(r.plan!.toTransfer.map((e) => e.enrollmentId), ['live']);
  });

  test('every error has a distinct Arabic message', () {
    final messages = AssignmentError.values.map(assignmentErrorMessage).toSet();
    expect(messages, hasLength(AssignmentError.values.length));
  });
}
