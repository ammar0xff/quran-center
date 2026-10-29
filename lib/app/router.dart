import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/features/authentication/screens/account_status_screen.dart';
import 'package:quran_center/features/authentication/screens/forgot_password_screen.dart';
import 'package:quran_center/features/authentication/screens/login_screen.dart';
import 'package:quran_center/features/authentication/screens/splash_screen.dart';
import 'package:quran_center/features/director/dashboard/director_dashboard_screen.dart';
import 'package:quran_center/features/director/students/add_student_screen.dart';
import 'package:quran_center/features/director/students/director_student_profile_screen.dart';
import 'package:quran_center/features/director/students/student_management_list_screen.dart';
import 'package:quran_center/features/director/teachers/teacher_management_list_screen.dart';

abstract class AppRoute {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const accountStatus = '/account-status';
  static const appShell = '/app';
  static const teacherDashboard = '/teacher/dashboard';
  static const studentDashboard = '/student/dashboard';
  static const directorDashboard = '/director/dashboard';
}

/// GoRouter with auth redirect.
final router = GoRouter(
  initialLocation: AppRoute.splash,
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final isLogin = state.matchedLocation == AppRoute.login;
    if (!loggedIn) return isLogin ? null : AppRoute.login;
    if (isLogin) return AppRoute.appShell;
    return null;
  },
  routes: [
    GoRoute(path: AppRoute.splash, builder: (_, __) => const SplashScreen()),
    GoRoute(path: AppRoute.login, builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: AppRoute.forgotPassword,
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoute.accountStatus,
      builder: (_, __) => const AccountStatusScreen(),
    ),
    GoRoute(
      path: AppRoute.appShell,
      builder: (_, __) => const DirectorDashboardScreen(),
    ),
    GoRoute(
      path: AppRoute.teacherDashboard,
      builder: (_, __) => const _PlaceholderScreen('Teacher Dashboard'),
    ),
    GoRoute(
      path: AppRoute.studentDashboard,
      builder: (_, __) => const _PlaceholderScreen('Student Dashboard'),
    ),
    GoRoute(
      path: AppRoute.directorDashboard,
      builder: (_, __) => const DirectorDashboardScreen(),
    ),
    GoRoute(
      path: '/director/students',
      builder: (_, __) => const StudentManagementListScreen(),
    ),
    GoRoute(
      path: '/director/students/add',
      builder: (_, __) => const AddStudentScreen(),
    ),
    GoRoute(
      path: '/director/students/:id',
      builder: (_, state) => DirectorStudentProfileScreen(studentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/director/teachers',
      builder: (_, __) => const TeacherManagementListScreen(),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title (placeholder)')),
    );
  }
}
