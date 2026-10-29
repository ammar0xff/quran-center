import 'package:quran_center/data/models/circle.dart';

/// Repository for [Circle] teaching groups.
abstract class CircleRepository {
  /// Get a circle by id.
  Future<Circle?> getCircle(String circleId);

  /// Create a circle.
  Future<void> createCircle(Circle circle);

  /// Update a circle.
  Future<void> updateCircle(Circle circle);

  /// Archive a circle — enrollment history is preserved.
  Future<void> archiveCircle(String circleId, {required String actorId, String? reason});

  /// Stream of circles in a center (real-time).
  Stream<List<Circle>> watchCirclesByCenter(String centerId);

  /// Future list of circles in a center.
  Future<List<Circle>> getCirclesByCenter(String centerId);

  /// Circles assigned to a teacher.
  Future<List<Circle>> getCirclesByTeacher(String teacherId);
}
