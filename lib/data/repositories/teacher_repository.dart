import 'package:quran_center/data/models/teacher.dart';

/// Repository for [Teacher] records.
abstract class TeacherRepository {
  /// Get a teacher by id.
  Future<Teacher?> getTeacher(String teacherId);

  /// Create a teacher.
  Future<void> createTeacher(Teacher teacher);

  /// Update a teacher.
  Future<void> updateTeacher(Teacher teacher);

  /// Teachers in a center.
  Future<List<Teacher>> getTeachersByCenter(String centerId);
}
