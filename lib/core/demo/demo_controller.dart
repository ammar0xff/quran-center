import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/data/datasources/demo_center_seed.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/models/enums.dart';

/// Controls whether the app is currently showing the interactive 3-in-1 demo mode.
final isDemoModeProvider = StateProvider<bool>((ref) => false);

/// The active role selected in the interactive demo mode (مديرة | محفّظ | طالب).
final demoActiveRoleProvider = StateProvider<UserRole>((ref) => UserRole.director);

/// The in-memory seeded data source used while in demo mode.
final demoDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return DemoCenterSeed.createSeededDataSource();
});

/// Utility to switch between roles inside the interactive demo mode.
void switchDemoRole(WidgetRef ref, BuildContext context, UserRole newRole) {
  ref.read(demoActiveRoleProvider.notifier).state = newRole;

  switch (newRole) {
    case UserRole.director:
      context.go(Routes.directorHome);
      break;
    case UserRole.teacher:
      context.go(Routes.teacherHome);
      break;
    case UserRole.student:
      context.go(Routes.studentHome);
      break;
    case UserRole.guardian:
      break;
  }
}

/// Activates demo mode and opens the Director dashboard of the demo center.
void enterDemoMode(WidgetRef ref, BuildContext context) {
  ref.read(demoActiveRoleProvider.notifier).state = UserRole.director;
  ref.read(isDemoModeProvider.notifier).state = true;
  context.go(Routes.directorHome);
}

/// Exits demo mode and returns to unauthenticated state.
void exitDemoMode(WidgetRef ref, BuildContext context) {
  ref.read(isDemoModeProvider.notifier).state = false;
  context.go(Routes.login);
}
