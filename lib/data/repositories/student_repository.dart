import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

/// Repository for [Student] educational profiles.
///
/// A student is an educational entity independent of login. [authUserId] is
/// optional/nullable.
abstract class StudentRepository {
  /// Get a student by id.
  Future<Student?> getStudent(String studentId);

  /// Create a student profile.
  Future<void> createStudent(Student student);

  /// Update a student profile.
  Future<void> updateStudent(Student student);

  /// Archives a student. Nothing is deleted: attendance, assessments and
  /// enrolment history stay. The status change and its audit entry are written
  /// atomically. Throws [StateError] if the student does not exist.
  Future<void> archiveStudent(
    String studentId, {
    required String actorId,
    required String actorRole,
    String? reason,
  });

  /// Edits the descriptive fields only. Status, login link and center are
  /// never touched. Writes only fields that actually changed plus an audit
  /// entry (previous/new values) in one batch, and does nothing - and writes no
  /// audit - when nothing changed. Returns whether anything was saved.
  /// Throws [StateError] if the student does not exist, [ArgumentError] if
  /// the name or level is blank.
  Future<bool> updateProfile(
    String studentId, {
    required String actorId,
    required String actorRole,
    required String fullName,
    String? preferredName,
    required String educationalLevel,
    String? adminNotes,
  });

  /// Reverses [archiveStudent] (status back to active), audited the same way.
  Future<void> reinstateStudent(
    String studentId, {
    required String actorId,
    required String actorRole,
    String? reason,
  });

  /// Stream of students in a center, optionally filtered by enrollment status.
  Stream<List<Student>> watchStudentsByCenter(
    String centerId, {
    EnrollmentStatus? status,
  });

  /// Future list of students in a center.
  Future<List<Student>> getStudentsByCenter(String centerId);

  /// Students assigned to a teacher (within teacher's authorized circles).
  Future<List<Student>> getStudentsByTeacher(String teacherId);
}
