import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/circle.dart';

/// Weekday labels in display order (week starts Saturday). Values are ISO
/// weekday numbers: 1 = Monday ... 7 = Sunday.
const weekDays = <(int, String)>[
  (6, 'السبت'),
  (7, 'الأحد'),
  (1, 'الاثنين'),
  (2, 'الثلاثاء'),
  (3, 'الأربعاء'),
  (4, 'الخميس'),
  (5, 'الجمعة'),
];

String formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay parseTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Converts the editor's map to model objects, in display-week order.
List<CircleWeeklySchedule> scheduleFromMap(Map<int, (String, String)> m) => [
      for (final (d, _) in weekDays)
        if (m.containsKey(d))
          CircleWeeklySchedule(dayOfWeek: d, startTime: m[d]!.$1, endTime: m[d]!.$2),
    ];

Map<int, (String, String)> scheduleToMap(List<CircleWeeklySchedule> list) =>
    {for (final w in list) w.dayOfWeek: (w.startTime, w.endTime)};

/// Choose the days a circle meets and a start/end time for EACH day.
class WeeklyScheduleEditor extends StatelessWidget {
  const WeeklyScheduleEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final Map<int, (String, String)> value;
  final ValueChanged<Map<int, (String, String)>> onChanged;
  final String? error;

  Future<void> _pick(BuildContext context, int day, {required bool start}) async {
    final current = value[day]!;
    final t = await showTimePicker(
      context: context,
      initialTime: parseTimeOfDay(start ? current.$1 : current.$2),
    );
    if (t == null) return;
    final text = formatTimeOfDay(t);
    onChanged({...value, day: start ? (text, current.$2) : (current.$1, text)});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DesignTokens.space8,
          children: [
            for (final (d, label) in weekDays)
              FilterChip(
                label: Text(label),
                selected: value.containsKey(d),
                onSelected: (on) {
                  final next = {...value};
                  if (on) {
                    next[d] = value.values.isEmpty ? ('08:00', '10:00') : value.values.last;
                  } else {
                    next.remove(d);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
        for (final (d, label) in weekDays)
          if (value.containsKey(d))
            Padding(
              padding: const EdgeInsets.only(top: DesignTokens.space8),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(label)),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(context, d, start: true),
                      child: Text('البداية ${value[d]!.$1}'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(context, d, start: false),
                      child: Text('النهاية ${value[d]!.$2}'),
                    ),
                  ),
                ],
              ),
            ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space8),
            child: Text(error!, style: const TextStyle(color: DesignTokens.error)),
          ),
      ],
    );
  }
}
