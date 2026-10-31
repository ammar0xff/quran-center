import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/auth/auth_gateway.dart';
import 'package:quran_center/core/demo/demo_controller.dart';
import 'package:quran_center/data/datasources/demo_center_seed.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';

final authGatewayProvider =
    Provider<AuthGateway>((ref) => FirebaseAuthGateway());

/// The current [AppSession]. Rebuilt whenever authentication changes: a signed
/// in uid has its authoritative `users/{uid}` profile fetched, and the role
/// and status come from that profile only.
///
/// On sign-out this emits `unauthenticated`; nothing role-specific is kept.
final sessionProvider = StreamProvider<AppSession>((ref) async* {
  final gateway = ref.watch(authGatewayProvider);
  final users = ref.watch(userRepositoryProvider);

  yield const AppSession.loading();
  await for (final uid in gateway.uidChanges()) {
    if (uid == null) {
      yield const AppSession.unauthenticated();
      continue;
    }
    yield const AppSession.loading();
    try {
      final profile = await users.getUser(uid);
      yield resolveSession(uid: uid, profile: profile);
    } catch (_) {
      yield const AppSession.blocked(BlockReason.loadFailed);
    }
  }
});

/// Synchronous view of the session for the router: `loading` until known.
/// In demo mode, it immediately reflects the selected demo role (director/teacher/student).
final currentSessionProvider = Provider<AppSession>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    final demoRole = ref.watch(demoActiveRoleProvider);
    final user = switch (demoRole) {
      UserRole.director => DemoCenterSeed.directorUser,
      UserRole.teacher => DemoCenterSeed.teacherUser,
      UserRole.student => DemoCenterSeed.studentUser,
      UserRole.guardian => DemoCenterSeed.studentUser,
    };
    final kind = switch (demoRole) {
      UserRole.director => SessionKind.director,
      UserRole.teacher => SessionKind.teacher,
      UserRole.student => SessionKind.student,
      UserRole.guardian => SessionKind.student,
    };
    return AppSession.signedIn(kind, user);
  }

  return ref.watch(sessionProvider).maybeWhen(
        data: (s) => s,
        orElse: () => const AppSession.loading(),
      );
});

/// The authenticated user performing an audited action.
class Actor {
  const Actor(this.id, this.role);
  final String id;
  final String role;
}

/// The signed-in user, taken from the resolved session (uid and role from the
/// authoritative profile). Throws when nobody is signed in: an audited action
/// must never be attributed to an unknown or default user.
final actorProvider = Provider<Actor>((ref) {
  final profile = ref.watch(currentSessionProvider).profile;
  if (profile == null) {
    throw StateError('No signed-in user to attribute this action to.');
  }
  return Actor(profile.uid, profile.role.toJson());
});

/// The signed-in user's center. Every query and write is scoped to this value;
/// it is never taken from screen input. Throws when nobody is signed in.
final centerIdProvider = Provider<String>((ref) {
  final profile = ref.watch(currentSessionProvider).profile;
  if (profile == null) {
    throw StateError('No signed-in user, so there is no center to scope to.');
  }
  return profile.centerId;
});
