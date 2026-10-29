import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

/// Kinds of scheduling conflict.
enum ConflictType { teacher, circle }

/// A detected conflict between a candidate session and an existing one.
class ScheduleConflict {
  const ScheduleConflict(this.type, this.existing);

  final ConflictType type;
  final Schedule existing;
}

/// Parses "HH:mm" into minutes since midnight. Returns null if invalid.
int? parseTimeOfDay(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// True when both times parse and [start] is strictly before [end].
bool isValidTimeRange(String start, String end) {
  final s = parseTimeOfDay(start);
  final e = parseTimeOfDay(end);
  return s != null && e != null && s < e;
}

/// Finds conflicts between [candidate] and [existing] sessions.
///
/// Two sessions conflict when they fall on the same calendar date, their time
/// ranges overlap (touching end/start is NOT an overlap), and they share the
/// teacher or the circle. Cancelled sessions and the candidate itself (same
/// scheduleId, used when editing) are ignored.
List<ScheduleConflict> findScheduleConflicts(
  Schedule candidate,
  Iterable<Schedule> existing,
) {
  final cs = parseTimeOfDay(candidate.startTime);
  final ce = parseTimeOfDay(candidate.endTime);
  if (cs == null || ce == null) return const [];

  final conflicts = <ScheduleConflict>[];
  for (final other in existing) {
    if (other.scheduleId == candidate.scheduleId) continue;
    if (other.status == SessionStatus.cancelled) continue;
    if (!other.date.isSameDate(candidate.date)) continue;

    final os = parseTimeOfDay(other.startTime);
    final oe = parseTimeOfDay(other.endTime);
    if (os == null || oe == null) continue;

    final overlaps = cs < oe && os < ce;
    if (!overlaps) continue;

    if (other.teacherId == candidate.teacherId) {
      conflicts.add(ScheduleConflict(ConflictType.teacher, other));
    }
    if (other.circleId == candidate.circleId) {
      conflicts.add(ScheduleConflict(ConflictType.circle, other));
    }
  }
  return conflicts;
}
