import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/features/authentication/screens/account_status_screen.dart';
import 'package:quran_center/features/authentication/screens/forgot_password_screen.dart';
import 'package:quran_center/features/authentication/screens/login_screen.dart';
import 'package:quran_center/features/authentication/screens/splash_screen.dart';
import 'package:quran_center/features/director/attendance/attendance_administration_screen.dart';
import 'package:quran_center/features/director/circles/circle_management_list_screen.dart';
import 'package:quran_center/features/director/circles/circle_detail_screen.dart';
import 'package:quran_center/features/director/circles/create_circle_screen.dart';
import 'package:quran_center/features/director/circles/edit_circle_screen.dart';
import 'package:quran_center/features/director/dashboard/director_dashboard_screen.dart';
import 'package:quran_center/features/director/enrollments/enrollment_assignment_screen.dart';
import 'package:quran_center/features/director/more/director_more_screen.dart';
import 'package:quran_center/features/director/schedules/schedule_management_screen.dart';
import 'package:quran_center/features/director/students/add_student_screen.dart';
import 'package:quran_center/features/director/students/director_student_profile_screen.dart';
import 'package:quran_center/features/director/students/edit_student_screen.dart';
import 'package:quran_center/features/director/students/student_management_list_screen.dart';
import 'package:quran_center/features/director/teachers/add_teacher_screen.dart';
import 'package:quran_center/features/director/teachers/teacher_management_list_screen.dart';
import 'package:quran_center/features/student/feedback/student_feedback_screen.dart';
import 'package:quran_center/features/student/home/student_home_screen.dart';
import 'package:quran_center/features/student/profile/student_profile_screen.dart';
import 'package:quran_center/features/student/schedule/student_schedule_screen.dart';
import 'package:quran_center/features/student/tasks/student_task_detail_screen.dart';
import 'package:quran_center/features/student/tasks/student_tasks_screen.dart';
import 'package:quran_center/features/teacher/circles/teacher_circles_screen.dart';
import 'package:quran_center/features/teacher/home/teacher_home_screen.dart';
import 'package:quran_center/features/teacher/more/teacher_more_screen.dart';
import 'package:quran_center/features/teacher/students/new_task_screen.dart';
import 'package:quran_center/features/teacher/students/teacher_student_profile_screen.dart';
import 'package:quran_center/features/teacher/students/teacher_students_screen.dart';
import 'package:quran_center/features/teacher/sessions/assessment_screen.dart';
import 'package:quran_center/features/teacher/sessions/teacher_session_screen.dart';

/// The application router.
///
/// Every navigation is checked against the current [AppSession] by
/// [redirectFor], so an unauthenticated, suspended, or wrong-role user cannot
/// reach a protected screen by URL, deep link or back button. The router is
/// re-evaluated whenever the session changes (sign-in, sign-out, suspension).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AppSession>(currentSessionProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(currentSessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.accountStatus,
        builder: (_, __) => const AccountStatusScreen(),
      ),

      // Director area
      GoRoute(
        path: Routes.directorHome,
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
        path: '/director/students/:id/edit',
        builder: (_, state) =>
            EditStudentScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/director/students/:id',
        builder: (_, state) =>
            DirectorStudentProfileScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/director/teachers',
        builder: (_, __) => const TeacherManagementListScreen(),
      ),
      GoRoute(
        path: '/director/teachers/add',
        builder: (_, __) => const AddTeacherScreen(),
      ),
      GoRoute(
        path: '/director/circles',
        builder: (_, __) => const CircleManagementListScreen(),
      ),
      GoRoute(
        path: '/director/circles/add',
        builder: (_, __) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/director/circles/:id',
        builder: (_, state) =>
            CircleDetailScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/director/circles/:id/edit',
        builder: (_, state) =>
            EditCircleScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/director/enrollments/assign',
        builder: (_, state) => EnrollmentAssignmentScreen(
          initialStudentId: state.uri.queryParameters['student'],
          initialCircleId: state.uri.queryParameters['circle'],
        ),
      ),
      GoRoute(
        path: '/director/schedules',
        builder: (_, __) => const ScheduleManagementScreen(),
      ),
      GoRoute(
        path: '/director/attendance',
        builder: (_, __) => const AttendanceAdministrationScreen(),
      ),
      GoRoute(
        path: '/director/more',
        builder: (_, __) => const DirectorMoreScreen(),
      ),

      // Teacher area
      GoRoute(
        path: Routes.teacherHome,
        builder: (_, __) => const TeacherHomeScreen(),
      ),
      GoRoute(
        path: '/teacher/students',
        builder: (_, __) => const TeacherStudentsScreen(),
      ),
      GoRoute(
        path: '/teacher/students/:id',
        builder: (_, state) =>
            TeacherStudentProfileScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/students/:id/tasks/new',
        builder: (_, state) => NewTaskScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/circles',
        builder: (_, __) => const TeacherCirclesScreen(),
      ),
      GoRoute(
        path: '/teacher/more',
        builder: (_, __) => const TeacherMoreScreen(),
      ),
      GoRoute(
        path: '/teacher/sessions/:id',
        builder: (_, state) =>
            TeacherSessionScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/sessions/:id/assess/:studentId',
        builder: (_, state) => AssessmentScreen(
          sessionId: state.pathParameters['id']!,
          studentId: state.pathParameters['studentId']!,
          studentName: state.uri.queryParameters['name'],
        ),
      ),

      // Student area
      GoRoute(
        path: Routes.studentHome,
        builder: (_, __) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/tasks',
        builder: (_, __) => const StudentTasksScreen(),
      ),
      GoRoute(
        path: '/student/tasks/:id',
        builder: (_, state) =>
            StudentTaskDetailScreen(taskId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/schedule',
        builder: (_, __) => const StudentScheduleScreen(),
      ),
      GoRoute(
        path: '/student/feedback',
        builder: (_, __) => const StudentFeedbackScreen(),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (_, __) => const StudentProfileScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
