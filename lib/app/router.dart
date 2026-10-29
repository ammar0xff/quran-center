import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/features/authentication/screens/splash_screen.dart';
import 'package:quran_center/features/authentication/screens/login_screen.dart';

// Route constants so routes are referenced by name, not strings.
abstract class AppRoute {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const pendingSuspended = '/account-status';
  static const teacherDashboard = '/teacher/dashboard';
  static const studentDashboard = '/student/dashboard';
  static const directorDashboard = '/director/dashboard';
}

/// GoRouter declaration with auth/role guards.
///
/// Guards are stubbed here and implemented in [lib/app/app_lifecycle.dart] /
/// authorization layer once Firebase Auth is wired. Unauthorized navigation
/// is prevented at the router level and by backend Security Rules.
final router = GoRouter(
  initialLocation: AppRoute.splash,
  routes: [
    GoRoute(path: AppRoute.splash, builder: (_, __) => const SplashScreen()),
    GoRoute(path: AppRoute.login, builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: AppRoute.forgotPassword,
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoute.pendingSuspended,
      builder: (_, __) => const AccountStatusScreen(),
    ),
    // Role shells registered after auth resolves (see app_lifecycle.dart).
  ],
  // redirect: (state) => _redirect(state), // wired in Phase 2 auth step
);

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Forgot Password (placeholder)')),
  );
}

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Account Status (placeholder)')),
  );
}
