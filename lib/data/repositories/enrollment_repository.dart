import 'package:quran_center/data/models/enrollment.dart';

/// Repository for [Enrollment] links between students and circles.
///
/// Enrollment history is preserved; a student may have multiple enrollment
/// records over time (transfers, re-enrollment).
abstract class EnrollmentRepository {
  /// Get an enrollment by id.
  Future<Enrollment?> getEnrollment(String enrollmentId);

  /// Create an enrollment.
  Future<void> createEnrollment(Enrollment enrollment);

  /// Update an enrollment (e.g. transfer, withdraw, archive).
  Future<void> updateEnrollment(Enrollment enrollment);

  /// Active enrollments for a student.
  Future<List<Enrollment>> getActiveEnrollmentsForStudent(String studentId);

  /// Active enrollments in a circle.
  Future<List<Enrollment>> getActiveEnrollmentsForCircle(String circleId);

  /// Stream of enrollments for a student (real-time).
  Stream<List<Enrollment>> watchEnrollmentsForStudent(String studentId);
}
