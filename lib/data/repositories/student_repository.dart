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

  /// Archive (soft-delete) a student — history is preserved.
  Future<void> archiveStudent(String studentId, {required String actorId, String? reason});

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
