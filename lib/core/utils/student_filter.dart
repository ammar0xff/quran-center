import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

/// Filter on whether the student has a login.
enum AccessFilter { any, noLogin, hasLogin }

/// Filters and orders the director's student list.
///
/// * [query] matches the full name, preferred name or student id
///   (case-insensitive, surrounding whitespace ignored). Email and phone are
///   never needed to find a student.
/// * [status] null means every enrolment status.
/// * [access]: `hasLogin` is any student whose access mode is not `none`
///   (enabled or suspended); `noLogin` is accountless students.
/// Results are ordered by name so the list is stable.
List<Student> filterStudents(
  Iterable<Student> students, {
  String query = '',
  EnrollmentStatus? status,
  AccessFilter access = AccessFilter.any,
}) {
  final q = query.trim().toLowerCase();
  final result = students.where((s) {
    if (status != null && s.enrollmentStatus != status) return false;
    switch (access) {
      case AccessFilter.any:
        break;
      case AccessFilter.noLogin:
        if (s.accountMode != AccountMode.none) return false;
      case AccessFilter.hasLogin:
        if (s.accountMode == AccountMode.none) return false;
    }
    if (q.isEmpty) return true;
    return s.fullName.toLowerCase().contains(q) ||
        (s.preferredName?.toLowerCase().contains(q) ?? false) ||
        s.studentId.toLowerCase().contains(q);
  }).toList();
  result.sort((a, b) => a.displayName.compareTo(b.displayName));
  return result;
}
