import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/student_filter.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

Student _s(
  String id,
  String name, {
  String? preferred,
  EnrollmentStatus status = EnrollmentStatus.active,
  AccountMode mode = AccountMode.none,
}) =>
    Student(
      studentId: id,
      centerId: 'c',
      fullName: name,
      preferredName: preferred,
      enrollmentStatus: status,
      accountMode: mode,
      educationalLevel: 'x',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final all = [
    _s('s_100', 'محمد أحمد'),
    _s('s_200', 'فاطمة علي', preferred: 'فطوم'),
    _s('s_300', 'خالد يوسف',
        status: EnrollmentStatus.archived, mode: AccountMode.loginEnabled),
    _s('S_400', 'Sara Ahmed', mode: AccountMode.suspended),
  ];

  List<String> ids(List<Student> l) => l.map((s) => s.studentId).toList();

  test('no filters returns everyone', () {
    expect(filterStudents(all), hasLength(4));
  });

  test('query matches full name, preferred name and id', () {
    expect(ids(filterStudents(all, query: 'فاطمة')), ['s_200']);
    expect(ids(filterStudents(all, query: 'فطوم')), ['s_200']);
    expect(ids(filterStudents(all, query: 's_300')), ['s_300']);
  });

  test('query ignores case and surrounding whitespace', () {
    expect(ids(filterStudents(all, query: '  sara ')), ['S_400']);
    expect(ids(filterStudents(all, query: 's_400')), ['S_400']);
  });

  test('blank query does not filter', () {
    expect(filterStudents(all, query: '   '), hasLength(4));
  });

  test('status filter', () {
    expect(ids(filterStudents(all, status: EnrollmentStatus.archived)), ['s_300']);
    expect(filterStudents(all, status: EnrollmentStatus.active), hasLength(3));
    expect(filterStudents(all, status: EnrollmentStatus.withdrawn), isEmpty);
  });

  test('access filter: accountless vs any login (enabled or suspended)', () {
    expect(ids(filterStudents(all, access: AccessFilter.noLogin)),
        unorderedEquals(['s_100', 's_200']));
    expect(ids(filterStudents(all, access: AccessFilter.hasLogin)),
        unorderedEquals(['s_300', 'S_400']));
  });

  test('filters combine', () {
    expect(
      ids(filterStudents(all,
          status: EnrollmentStatus.active,
          access: AccessFilter.hasLogin,
          query: 'sara')),
      ['S_400'],
    );
    expect(
      filterStudents(all,
          status: EnrollmentStatus.archived, access: AccessFilter.noLogin),
      isEmpty,
    );
  });

  test('results are ordered by display name', () {
    final names = filterStudents(all).map((s) => s.displayName).toList();
    final sorted = [...names]..sort();
    expect(names, sorted);
  });
}
