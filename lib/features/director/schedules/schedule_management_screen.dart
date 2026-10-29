import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';
import 'package:quran_center/features/director/schedules/create_session_sheet.dart';

enum ScheduleView { list, daily, weekly }

String sessionStatusLabel(SessionStatus s) {
  switch (s) {
    case SessionStatus.scheduled:
      return 'مجدولة';
    case SessionStatus.inProgress:
      return 'جارية';
    case SessionStatus.completed:
      return 'منجزة';
    case SessionStatus.cancelled:
      return 'ملغاة';
  }
}

Color sessionStatusColor(SessionStatus s) {
  switch (s) {
    case SessionStatus.scheduled:
      return DesignTokens.informational;
    case SessionStatus.inProgress:
      return DesignTokens.warning;
    case SessionStatus.completed:
      return DesignTokens.success;
    case SessionStatus.cancelled:
      return DesignTokens.error;
  }
}

/// Start of the week (Saturday) containing [d].
DateTime weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final offset = (day.weekday - DateTime.saturday) % 7;
  return day.subtract(Duration(days: offset));
}

/// Director schedule management: list / daily / weekly views, filters,
/// and session creation with conflict detection.
class ScheduleManagementScreen extends ConsumerStatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  ConsumerState<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState
    extends ConsumerState<ScheduleManagementScreen> {
  ScheduleView _view = ScheduleView.list;
  DateTime _anchor = DateTime.now();
  String? _circleFilter;
  SessionStatus? _statusFilter;
  List<Schedule> _schedules = [];
  Map<String, String> _circleNames = {};
  Map<String, String> _teacherNames = {};
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final schedules =
          await ref.read(scheduleRepositoryProvider).getSchedulesByCenter('center-1');
      final circles =
          await ref.read(circleRepositoryProvider).getCirclesByCenter('center-1');
      final teachers =
          await ref.read(teacherRepositoryProvider).getTeachersByCenter('center-1');
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _circleNames = {for (final c in circles) c.circleId: c.name};
        _teacherNames = {for (final t in teachers) t.teacherId: t.fullName};
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'تعذر تحميل الجدول';
      });
    }
  }

  List<Schedule> get _visible {
    final start = weekStart(_anchor);
    final end = start.add(const Duration(days: 7));
    final list = _schedules.where((s) {
      if (_circleFilter != null && s.circleId != _circleFilter) return false;
      if (_statusFilter != null && s.status != _statusFilter) return false;
      switch (_view) {
        case ScheduleView.list:
          return true;
        case ScheduleView.daily:
          return s.date.isSameDate(_anchor);
        case ScheduleView.weekly:
          return !s.date.isBefore(start) && s.date.isBefore(end);
      }
    }).toList();
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  void _shift(int days) =>
      setState(() => _anchor = _anchor.add(Duration(days: days)));

  Future<void> _openCreate() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateSessionSheet(
        circles: _circleNames.entries
            .map((e) => PickerOption(e.key, e.value))
            .toList(),
        teachers: _teacherNames.entries
            .map((e) => PickerOption(e.key, e.value))
            .toList(),
        existing: _schedules,
        onSave: (s) => ref.read(scheduleRepositoryProvider).createSchedule(s),
      ),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إنشاء الجلسة'),
        backgroundColor: DesignTokens.success,
      ));
    }
  }

  String get _rangeLabel {
    final f = DateFormat.MMMd('ar');
    switch (_view) {
      case ScheduleView.list:
        return 'كل الجلسات';
      case ScheduleView.daily:
        return DateFormat.yMMMMEEEEd('ar').format(_anchor);
      case ScheduleView.weekly:
        final s = weekStart(_anchor);
        return '${f.format(s)} - ${f.format(s.add(const Duration(days: 6)))}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          title: const Text('إدارة الجدول'),
          centerTitle: false,
          actions: [
            FilledButton.icon(
              onPressed: _loading ? null : _openCreate,
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text('إنشاء جلسة'),
            ),
            const SizedBox(width: DesignTokens.space12),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space16),
              child: SegmentedButton<ScheduleView>(
                segments: const [
                  ButtonSegment(
                      value: ScheduleView.list,
                      label: Text('قائمة'),
                      icon: Icon(Icons.list)),
                  ButtonSegment(
                      value: ScheduleView.daily,
                      label: Text('يومي'),
                      icon: Icon(Icons.today)),
                  ButtonSegment(
                      value: ScheduleView.weekly,
                      label: Text('أسبوعي'),
                      icon: Icon(Icons.calendar_view_week)),
                ],
                selected: {_view},
                onSelectionChanged: (set) => setState(() => _view = set.first),
              ),
            ),
            if (_view != ScheduleView.list)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'السابق',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shift(_view == ScheduleView.weekly ? -7 : -1),
                  ),
                  Text(_rangeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    tooltip: 'التالي',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shift(_view == ScheduleView.weekly ? 7 : 1),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space20, vertical: DesignTokens.space8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _circleFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'الحلقة', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('كل الحلقات')),
                        ..._circleNames.entries.map((e) =>
                            DropdownMenuItem<String?>(
                                value: e.key, child: Text(e.value))),
                      ],
                      onChanged: (v) => setState(() => _circleFilter = v),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: DropdownButtonFormField<SessionStatus?>(
                      value: _statusFilter,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'الحالة', isDense: true),
                      items: [
                        const DropdownMenuItem<SessionStatus?>(
                            value: null, child: Text('كل الحالات')),
                        ...SessionStatus.values.map((s) =>
                            DropdownMenuItem<SessionStatus?>(
                                value: s, child: Text(sessionStatusLabel(s)))),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? _stateMessage(Icons.error_outline, _loadError!, 'إعادة المحاولة', _load)
                      : items.isEmpty
                          ? _stateMessage(
                              Icons.schedule,
                              _schedules.isEmpty
                                  ? 'لا توجد جلسات'
                                  : 'لا توجد جلسات مطابقة',
                              _schedules.isEmpty ? 'إنشاء جلسة' : 'مسح الفلاتر',
                              _schedules.isEmpty
                                  ? _openCreate
                                  : () => setState(() {
                                        _circleFilter = null;
                                        _statusFilter = null;
                                      }),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (_, i) => _ScheduleCard(
                                schedule: items[i],
                                circleName:
                                    _circleNames[items[i].circleId] ?? items[i].circleId,
                                teacherName: _teacherNames[items[i].teacherId] ??
                                    items[i].teacherId,
                              ),
                            ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          items: const [
            BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard, activeIcon: Icons.dashboard),
            BottomNavItem(label: 'الطلاب', icon: Icons.people, activeIcon: Icons.people),
            BottomNavItem(label: 'المعلمون', icon: Icons.person, activeIcon: Icons.person),
            BottomNavItem(label: 'الحلقات', icon: Icons.school, activeIcon: Icons.school),
            BottomNavItem(label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu),
          ],
          currentIndex: 4,
          onTap: (i) {},
        ),
      ),
    );
  }

  Widget _stateMessage(
      IconData icon, String message, String actionLabel, VoidCallback onAction) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: DesignTokens.secondaryText),
          const SizedBox(height: DesignTokens.space16),
          Text(message,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.mainText)),
          const SizedBox(height: DesignTokens.space16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.circleName,
    required this.teacherName,
  });

  final Schedule schedule;
  final String circleName;
  final String teacherName;

  @override
  Widget build(BuildContext context) {
    final color = sessionStatusColor(schedule.status);
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space20, vertical: DesignTokens.space8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16, vertical: DesignTokens.space8),
        leading: CircleAvatar(
          backgroundColor: DesignTokens.softMint,
          child: Text(
            DateFormat.Md('ar').format(schedule.date),
            style: const TextStyle(
                color: DesignTokens.primaryDarkGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
        title: Text(circleName,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DesignTokens.mainText)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: DesignTokens.space4),
          child: Wrap(
            spacing: DesignTokens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space8, vertical: DesignTokens.space4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                  border: Border.all(color: color),
                ),
                child: Text(sessionStatusLabel(schedule.status),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
              Text('${schedule.startTime} - ${schedule.endTime}',
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
              Text(teacherName,
                  style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondaryText)),
            ],
          ),
        ),
      ),
    );
  }
}
