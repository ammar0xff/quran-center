import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';
import 'package:quran_center/design_system/components/kpi_card.dart';
import 'package:quran_center/design_system/components/section_header.dart';

/// Director dashboard — primary operational overview.
///
/// All KPIs are calculated from real, authorized data (mocked here until the
/// director repositories are wired to Firebase in Phase 4/5).
class DirectorDashboardScreen extends StatefulWidget {
  const DirectorDashboardScreen({super.key});

  @override
  State<DirectorDashboardScreen> createState() => _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState extends State<DirectorDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat.yMMMMd('ar').format(now);
    final dayStr = DateFormat.EEEE('ar').format(now);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: Column(
            children: [
              // App bar
              _buildAppBar(context, dateStr, dayStr),
              const SizedBox(height: DesignTokens.space20),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        'أهلاً بك، مديرة الدار',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.mainText,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space4),
                      Text(
                        'ملخص العمليات اليومية لمركزك',
                        style: TextStyle(
                          fontSize: 14,
                          color: DesignTokens.secondaryText,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space24),

                      // KPI cards
                      _buildKpiGrid(),
                      const SizedBox(height: DesignTokens.space24),

                      // Today's operational summary
                      SectionHeader(
                        title: 'ملخص العمليات اليوم',
                        onSeeAll: () {},
                      ),
                      _buildOperationalSummary(),
                      const SizedBox(height: DesignTokens.space24),

                      // Attendance overview
                      SectionHeader(
                        title: 'نظرة على الحضور',
                        subtitle: 'آخر 7 أيام',
                        onSeeAll: () {},
                      ),
                      _buildAttendanceOverview(),
                      const SizedBox(height: DesignTokens.space24),

                      // Educational follow-up
                      SectionHeader(
                        title: 'متابعة تعليمية',
                        subtitle: 'طلاب يحتاجون متابعة',
                        onSeeAll: () {},
                      ),
                      _buildFollowUpList(),
                      const SizedBox(height: DesignTokens.space24),

                      // Teacher activity
                      SectionHeader(
                        title: 'نشاط المعلمين',
                        onSeeAll: () {},
                      ),
                      _buildTeacherActivity(),
                      const SizedBox(height: DesignTokens.space32),

                      // Quick actions
                      SectionHeader(
                        title: 'إجراءات سريعة',
                        onSeeAll: () {},
                      ),
                      _buildQuickActions(),
                      const SizedBox(height: DesignTokens.space40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNav(
          items: const [
            BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard, activeIcon: Icons.dashboard),
            BottomNavItem(label: 'الطلاب', icon: Icons.people, activeIcon: Icons.people),
            BottomNavItem(label: 'الحلقات', icon: Icons.school, activeIcon: Icons.school),
            BottomNavItem(label: 'التقارير', icon: Icons.insert_chart, activeIcon: Icons.insert_chart),
            BottomNavItem(label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu),
          ],
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String dateStr, String dayStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space8),
            decoration: BoxDecoration(
              color: DesignTokens.primaryDarkGreen,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 24),
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دار تحفيظ القرآن',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.mainText,
                  ),
                ),
                Text(
                  '$dayStr • $dateStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: DesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 24),
                color: DesignTokens.secondaryText,
                onPressed: () {},
              ),
              const SizedBox(width: DesignTokens.space8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: DesignTokens.primaryDarkGreen,
                child: Text('م', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      crossAxisSpacing: DesignTokens.space16,
      mainAxisSpacing: DesignTokens.space16,
      children: [
        KpiCard(
          value: '142',
          label: 'طلاب منتظمون',
          icon: Icons.people_outline,
          color: DesignTokens.primaryDarkGreen,
          onTap: () {},
        ),
        KpiCard(
          value: '12',
          label: 'معلمون نشطون',
          icon: Icons.person_outline,
          color: DesignTokens.informational,
          onTap: () {},
        ),
        KpiCard(
          value: '8',
          label: 'حلقة نشطة',
          icon: Icons.school_outlined,
          color: DesignTokens.success,
          onTap: () {},
        ),
        KpiCard(
          value: '6',
          label: 'جلسات مجدولة اليوم',
          icon: Icons.today,
          color: DesignTokens.warning,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildOperationalSummary() {
    final statuses = [
      ('مجدولة', '4', DesignTokens.informational),
      ('جارية', '1', DesignTokens.warning),
      ('لم تبدأ بعد', '3', DesignTokens.secondaryText),
      ('سجلات ناقصة', '0', DesignTokens.success),
    ];
    return Row(
      children: statuses.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: DesignTokens.space12),
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space16, horizontal: DesignTokens.space12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(color: DesignTokens.borders),
            ),
            child: Column(
              children: [
                Text(
                  s.$2,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.mainText,
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),
                Text(
                  s.$1,
                  style: TextStyle(
                    fontSize: 12,
                    color: s.$3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceOverview() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معدل الحضور',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          Row(
            children: [
              Expanded(
                child: _buildStatColumn('94%', 'حضور', DesignTokens.success),
              ),
              Container(width: 1, height: 40, color: DesignTokens.borders),
              Expanded(
                child: _buildStatColumn('4%', 'غياب', DesignTokens.error),
              ),
              Container(width: 1, height: 40, color: DesignTokens.borders),
              Expanded(
                child: _buildStatColumn('2%', 'تأخير', DesignTokens.warning),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('عرض التقرير المفصل'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: DesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpList() {
    final items = [
      ('طالب يحتاج مراجعة', 'مراجعة بعيدة مستحقة', 'منذ 3 أيام'),
      ('طالب غائب متكرر', 'غيابان متتاليان', 'أمس'),
      ('حلقة سجلات ناقصة', 'جلسة غير مغقاة', 'اليوم'),
    ];
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: DesignTokens.space12),
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.borders),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: DesignTokens.warning, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.mainText,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      '${item.$2} • ${item.$3}',
                      style: TextStyle(
                        fontSize: 13,
                        color: DesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: DesignTokens.secondaryText),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeacherActivity() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'جلسات مسجلة اليوم',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: DesignTokens.mainText,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          Row(
            children: [
              Expanded(
                child: _buildStatColumn('8', 'جلسات', DesignTokens.primaryDarkGreen),
              ),
              Container(width: 1, height: 40, color: DesignTokens.borders),
              Expanded(
                child: _buildStatColumn('100%', 'تسجيل الحضور', DesignTokens.success),
              ),
              Container(width: 1, height: 40, color: DesignTokens.borders),
              Expanded(
                child: _buildStatColumn('6', 'تسجيلات تقييم', DesignTokens.informational),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('عرض نشاط المعلمين'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('إضافة طالب', Icons.person_add, DesignTokens.primaryDarkGreen),
      ('إضافة معلم', Icons.person_add_alt, DesignTokens.informational),
      ('إنشاء حلقة', Icons.school, DesignTokens.success),
      ('إدارة الجدول', Icons.schedule, DesignTokens.warning),
      ('الحضور', Icons.check_circle, DesignTokens.success),
      ('إصدار تقرير', Icons.insert_chart, DesignTokens.informational),
      ('إعلان', Icons.announcement, DesignTokens.error),
    ];
    return Wrap(
      spacing: DesignTokens.space12,
      runSpacing: DesignTokens.space12,
      children: actions.map((a) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 40 - 12) / 2 - 6,
          child: ActionChip(
            avatar: CircleAvatar(
              radius: 14,
              backgroundColor: a.$3.withValues(alpha: 0.1),
              child: Icon(a.$2, color: a.$3, size: 18),
            ),
            label: Text(
              a.$1,
              style: const TextStyle(fontSize: 13, color: DesignTokens.mainText, fontWeight: FontWeight.w600),
            ),
            onPressed: () {},
          ),
        );
      }).toList(),
    );
  }
}
