import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Primary navigation for the student area.
class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const paths = <String>[
    Routes.studentHome,
    '/student/tasks',
    '/student/schedule',
    '/student/feedback',
    '/student/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomBottomNav(
        items: const [
          BottomNavItem(label: 'الرئيسية', icon: Icons.home),
          BottomNavItem(label: 'مهامي', icon: Icons.checklist),
          BottomNavItem(label: 'الجدول', icon: Icons.calendar_month),
          BottomNavItem(label: 'الملاحظات', icon: Icons.rate_review),
          BottomNavItem(label: 'حسابي', icon: Icons.person),
        ],
        currentIndex: currentIndex,
        onTap: (i) {
          if (i != currentIndex) context.go(paths[i]);
        },
      ),
    );
  }
}
