import 'package:quran_center/data/models/schedule.dart';

/// Repository for [Schedule] scheduled teaching sessions.
abstract class ScheduleRepository {
  /// Get a schedule by id.
  Future<Schedule?> getSchedule(String scheduleId);

  /// Create a schedule.
  Future<void> createSchedule(Schedule schedule);

  /// Update a schedule (e.g. reschedule).
  Future<void> updateSchedule(Schedule schedule);

  /// Cancel a schedule with reason + actor.
  Future<void> cancelSchedule(
    String scheduleId, {
    required String actorId,
    required String reason,
  });

  /// Schedules in a center, optionally filtered by circle/teacher/date.
  Future<List<Schedule>> getSchedulesByCenter(
    String centerId, {
    String? circleId,
    String? teacherId,
    DateTime? date,
  });

  /// Stream of schedules in a center (real-time).
  Stream<List<Schedule>> watchSchedulesByCenter(
    String centerId, {
    String? circleId,
    String? teacherId,
    DateTime? date,
  });
}
