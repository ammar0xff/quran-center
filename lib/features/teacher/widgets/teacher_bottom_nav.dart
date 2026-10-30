import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/design_system/components/custom_bottom_nav.dart';

/// Primary navigation for the teacher area.
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const paths = <String>[
    Routes.teacherHome,
    '/teacher/circles',
    '/teacher/more',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomBottomNav(
        items: const [
          BottomNavItem(label: 'الرئيسية', icon: Icons.home),
          BottomNavItem(label: 'حلقاتي', icon: Icons.school),
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
