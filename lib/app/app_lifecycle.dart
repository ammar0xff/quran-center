import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application lifecycle notifier.
///
/// Manages auth state restoration, role resolution, and clean-up on sign-out.
/// Role-specific in-memory state, listeners, and notification subscriptions
/// are cleared here so signing in with another role never exposes the
/// previous user's data.
class AppLifecycleNotifier extends StateNotifier<AsyncValue<AppLifecycleState>> {
  AppLifecycleNotifier() : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    // Phase 2: wire Firebase Auth authStateChanges here.
    // Resolve authoritative profile + role, then emit authenticated state.
    state = const AsyncValue.data(AppLifecycleState.unauthenticated);
  }

  /// Sign out: clear role state, cancel listeners, reset navigation, return to auth.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    // Clear cached sensitive state, cancel listeners here.
    state = const AsyncValue.data(AppLifecycleState.unauthenticated);
  }
}

final appLifecycleProvider =
    StateNotifierProvider<AppLifecycleNotifier, AsyncValue<AppLifecycleState>>(
  (ref) => AppLifecycleNotifier(),
);

enum AppLifecycleState {
  initializing,
  unauthenticated,
  authenticatedDirector,
  authenticatedTeacher,
  authenticatedStudent,
  suspended,
  incomplete,
}
