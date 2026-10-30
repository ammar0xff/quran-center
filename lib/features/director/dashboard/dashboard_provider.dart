import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/utils/dashboard_stats.dart';
import 'package:quran_center/data/providers/repositories.dart';

/// Loads the signed-in director's center data and derives the dashboard
/// numbers. Re-evaluated each time the dashboard is opened.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final (students, teachers, circles, schedules, attendance) = await (
    ref.watch(studentRepositoryProvider).getStudentsByCenter(centerId),
    ref.watch(teacherRepositoryProvider).getTeachersByCenter(centerId),
    ref.watch(circleRepositoryProvider).getCirclesByCenter(centerId),
    ref.watch(scheduleRepositoryProvider).getSchedulesByCenter(centerId),
    ref.watch(attendanceRepositoryProvider).getByCenter(centerId),
  ).wait;
  return computeDashboardStats(
    students: students,
    teachers: teachers,
    circles: circles,
    schedules: schedules,
    attendance: attendance,
    now: DateTime.now(),
  );
});
