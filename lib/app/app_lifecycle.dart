import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/data/models/enums.dart';

/// Application lifecycle + auth state.
///
/// Restores the Firebase Auth session, resolves the authoritative role from
/// the user profile + custom claims, and exposes it so the router can gate
/// navigation. On sign-out, clears role state so another role never leaks
/// the previous user's data.
class AppLifecycleNotifier extends StateNotifier<AsyncValue<AppLifecycleState>> {
  AppLifecycleNotifier() : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data(AppLifecycleState.unauthenticated);
        return;
      }
      // Phase 4: resolve authoritative profile + role from users/{uid} +
      // custom claims. For now, emit authenticated states keyed on a
      // placeholder role until the user repository is wired.
      state = const AsyncValue.data(AppLifecycleState.authenticatedTeacher);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Sign out: clear role state, cancel listeners, reset navigation.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await FirebaseAuth.instance.signOut();
    state = const AsyncValue.data(AppLifecycleState.unauthenticated);
  }
}

final appLifecycleProvider =
    StateNotifierProvider<AppLifecycleNotifier, AsyncValue<AppLifecycleState>>(
  (ref) => AppLifecycleNotifier(),
);

/// Current resolved role (read by the router guard).
final currentRoleProvider = Provider<UserRole?>((ref) {
  final state = ref.watch(appLifecycleProvider);
  return state.maybeWhen(
    data: (s) => _roleFrom(s),
    orElse: () => null,
  );
});

UserRole? _roleFrom(AppLifecycleState s) {
  switch (s) {
    case AppLifecycleState.authenticatedDirector:
      return UserRole.director;
    case AppLifecycleState.authenticatedTeacher:
      return UserRole.teacher;
    case AppLifecycleState.authenticatedStudent:
      return UserRole.student;
    default:
      return null;
  }
}

enum AppLifecycleState {
  initializing,
  unauthenticated,
  authenticatedDirector,
  authenticatedTeacher,
  authenticatedStudent,
  suspended,
  incomplete,
}
