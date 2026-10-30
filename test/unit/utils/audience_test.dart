import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/audience.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/user.dart';

final _t = DateTime(2026);

User _u(String id, UserRole role, {AccountStatus status = AccountStatus.active}) => User(
    uid: id, centerId: 'c', fullName: id, role: role, status: status,
    authProvider: 'password', createdAt: _t, updatedAt: _t);

Student _s(String id, {String? login, String? circle, EnrollmentStatus st = EnrollmentStatus.active}) =>
    Student(studentId: id, centerId: 'c', fullName: id, enrollmentStatus: st,
        accountMode: login == null ? AccountMode.none : AccountMode.loginEnabled,
        authUserId: login, currentCircleId: circle, educationalLevel: 'x', createdAt: _t, updatedAt: _t);

Circle _c(String id, {String? teacher}) => Circle(
    circleId: id, centerId: 'c', name: id, educationalLevel: 'x', assignedTeacherId: teacher,
    maxCapacity: 5, locationOrMode: 'onsite', weeklySchedule: const [],
    sessionDurationMinutes: 60, status: CircleStatus.active, createdAt: _t, updatedAt: _t);

void main() {
  final users = [
    _u('dir', UserRole.director),
    _u('t1', UserRole.teacher),
    _u('t2', UserRole.teacher),
    _u('tSusp', UserRole.teacher, status: AccountStatus.suspended),
    _u('u1', UserRole.student),
    _u('u2', UserRole.student),
    _u('u3', UserRole.student),
  ];
  final students = [
    _s('s1', login: 'u1', circle: 'cA'),
    _s('s2', login: 'u2', circle: 'cB'),
    _s('s3', circle: 'cA'), // no login: nobody to notify
    _s('s4', login: 'u3', circle: 'cA', st: EnrollmentStatus.archived),
  ];
  final circles = [_c('cA', teacher: 't1'), _c('cB', teacher: 'tSusp')];

  Set<String> run(AudienceType a, [List<String> ids = const []]) => resolveAudience(
      audience: a, targetIds: ids, senderId: 'dir', users: users, students: students, circles: circles);

  test('everyone active, except the sender and suspended accounts', () {
    expect(run(AudienceType.all), {'t1', 't2', 'u1', 'u2', 'u3'});
  });
  test('teachers only / students with accounts only', () {
    expect(run(AudienceType.teachers), {'t1', 't2'});
    expect(run(AudienceType.studentsWithAccount), {'u1', 'u2', 'u3'});
  });
  test('a circle reaches its students with a login and its teacher, not archived or accountless ones', () {
    expect(run(AudienceType.selectedCircles, ['cA']), {'u1', 't1'});
  });
  test('a circle whose teacher is suspended does not notify the teacher', () {
    expect(run(AudienceType.selectedCircles, ['cB']), {'u2'});
  });
  test('several circles combine; no circles means nobody', () {
    expect(run(AudienceType.selectedCircles, ['cA', 'cB']), {'u1', 't1', 'u2'});
    expect(run(AudienceType.selectedCircles), isEmpty);
  });
  test('selected users must be real active members', () {
    expect(run(AudienceType.selectedUsers, ['t1', 'tSusp', 'ghost', 'dir']), {'t1'});
  });
  test('labels are distinct', () {
    expect(AudienceType.values.map(audienceLabel).toSet(), hasLength(AudienceType.values.length));
  });
}
