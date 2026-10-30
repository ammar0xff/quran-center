import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Primary navigation for the director area. Each tab replaces the current
/// section (no back-stack growth when hopping between sections).
class DirectorBottomNav extends StatelessWidget {
  const DirectorBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const paths = <String>[
    Routes.directorHome,
    '/director/students',
    '/director/teachers',
    '/director/circles',
    '/director/more',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomBottomNav(
        items: const [
          BottomNavItem(label: 'نظرة عامة', icon: Icons.dashboard),
          BottomNavItem(label: 'الطلاب', icon: Icons.people),
          BottomNavItem(label: 'المعلمون', icon: Icons.person),
          BottomNavItem(label: 'الحلقات', icon: Icons.school),
          BottomNavItem(label: 'المزيد', icon: Icons.menu),
        ],
        currentIndex: currentIndex,
        onTap: (i) {
          if (i != currentIndex) context.go(paths[i]);
        },
      ),
    );
  }
}
