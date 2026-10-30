import 'package:quran_center/core/utils/schedule_conflicts.dart';

/// Field problems for the Create Circle form. `null` means the field is valid.
class CircleFormErrors {
  const CircleFormErrors({this.name, this.capacity, this.duration, this.schedule});

  final String? name;
  final String? capacity;
  final String? duration;
  final String? schedule;

  bool get hasErrors =>
      name != null || capacity != null || duration != null || schedule != null;
}

const int maxCircleCapacity = 500;
const int minSessionMinutes = 5;
const int maxSessionMinutes = 480;

/// Validates raw form text. Whitespace is trimmed; numbers must be whole.
///
/// [scheduleDays] are the chosen weekdays (ISO: 1 = Monday ... 7 = Sunday);
/// when any are chosen, [start] must be before [end].
CircleFormErrors validateCircleForm({
  required String name,
  required String capacity,
  required String duration,
  required Set<int> scheduleDays,
  required String start,
  required String end,
}) {
  String? nameError;
  if (name.trim().isEmpty) nameError = 'اسم الحلقة مطلوب';

  String? capacityError;
  final cap = int.tryParse(capacity.trim());
  if (capacity.trim().isEmpty) {
    capacityError = 'السعة مطلوبة';
  } else if (cap == null) {
    capacityError = 'أدخل رقمًا صحيحًا';
  } else if (cap < 1 || cap > maxCircleCapacity) {
    capacityError = 'السعة بين 1 و $maxCircleCapacity';
  }

  String? durationError;
  final dur = int.tryParse(duration.trim());
  if (duration.trim().isEmpty) {
    durationError = 'مدة الجلسة مطلوبة';
  } else if (dur == null) {
    durationError = 'أدخل رقمًا صحيحًا';
  } else if (dur < minSessionMinutes || dur > maxSessionMinutes) {
    durationError = 'المدة بين $minSessionMinutes و $maxSessionMinutes دقيقة';
  }

  String? scheduleError;
  if (scheduleDays.any((d) => d < 1 || d > 7)) {
    scheduleError = 'يوم غير صالح';
  } else if (scheduleDays.isNotEmpty && !isValidTimeRange(start, end)) {
    scheduleError = 'وقت البداية يجب أن يسبق وقت النهاية';
  }

  return CircleFormErrors(
    name: nameError,
    capacity: capacityError,
    duration: durationError,
    schedule: scheduleError,
  );
}
