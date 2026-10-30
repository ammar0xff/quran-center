import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/user.dart';

/// What the app knows about the person using it right now.
enum SessionKind { loading, unauthenticated, director, teacher, student, blocked }

/// Why a signed-in user was not let into a role shell.
enum BlockReason {
  noProfile,
  suspended,
  pending,
  incomplete,
  unsupportedRole,

  /// The profile could not be fetched (offline, backend error). Not a verdict
  /// about the account: the UI offers a retry.
  loadFailed,
}

class AppSession {
  const AppSession._(this.kind, {this.profile, this.blockReason});

  const AppSession.loading() : this._(SessionKind.loading);
  const AppSession.unauthenticated() : this._(SessionKind.unauthenticated);
  const AppSession.signedIn(SessionKind kind, User profile)
      : this._(kind, profile: profile);
  const AppSession.blocked(BlockReason reason, {User? profile})
      : this._(SessionKind.blocked, blockReason: reason, profile: profile);

  final SessionKind kind;
  final User? profile;
  final BlockReason? blockReason;

  bool get isSignedInWithRole =>
      kind == SessionKind.director ||
      kind == SessionKind.teacher ||
      kind == SessionKind.student;

  /// Home route for this session, or null when there is none yet.
  String? get homeRoute => switch (kind) {
        SessionKind.director => Routes.directorHome,
        SessionKind.teacher => Routes.teacherHome,
        SessionKind.student => Routes.studentHome,
        SessionKind.blocked => Routes.accountStatus,
        SessionKind.unauthenticated => Routes.login,
        SessionKind.loading => null,
      };
}

/// Route paths shared by the router and the guards.
abstract class Routes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const accountStatus = '/account-status';
  static const directorHome = '/director/dashboard';
  static const teacherHome = '/teacher/home';
  static const studentHome = '/student/home';
}

/// Turns the authenticated uid and the authoritative `users/{uid}` profile
/// into a session. The role comes ONLY from the stored profile, never from
/// anything the client supplied.
///
/// A user with no profile, an inactive profile, or an unsupported role is
/// blocked: they reach no protected screen.
AppSession resolveSession({required String? uid, required User? profile}) {
  if (uid == null) return const AppSession.unauthenticated();
  if (profile == null || profile.uid != uid) {
    return const AppSession.blocked(BlockReason.noProfile);
  }
  switch (profile.status) {
    case AccountStatus.suspended:
      return AppSession.blocked(BlockReason.suspended, profile: profile);
    case AccountStatus.pending:
      return AppSession.blocked(BlockReason.pending, profile: profile);
    case AccountStatus.incomplete:
      return AppSession.blocked(BlockReason.incomplete, profile: profile);
    case AccountStatus.active:
      break;
  }
  switch (profile.role) {
    case UserRole.director:
      return AppSession.signedIn(SessionKind.director, profile);
    case UserRole.teacher:
      return AppSession.signedIn(SessionKind.teacher, profile);
    case UserRole.student:
      return AppSession.signedIn(SessionKind.student, profile);
    case UserRole.guardian:
      // Guardian access is not part of the initial release.
      return AppSession.blocked(BlockReason.unsupportedRole, profile: profile);
  }
}

/// Router guard: where should [session] be sent when it asks for [location]?
/// Returns null to allow the navigation.
///
/// * loading           -> splash only
/// * unauthenticated   -> login / forgot-password only
/// * blocked           -> account-status only
/// * director/teacher/student -> only their own area; anything else (auth
///   screens, another role's area, unknown paths) goes to their home.
String? redirectFor(AppSession session, String location) {
  switch (session.kind) {
    case SessionKind.loading:
      return location == Routes.splash ? null : Routes.splash;
    case SessionKind.unauthenticated:
      return (location == Routes.login || location == Routes.forgotPassword)
          ? null
          : Routes.login;
    case SessionKind.blocked:
      return location == Routes.accountStatus ? null : Routes.accountStatus;
    case SessionKind.director:
      return _inArea(location, '/director') ? null : Routes.directorHome;
    case SessionKind.teacher:
      return _inArea(location, '/teacher') ? null : Routes.teacherHome;
    case SessionKind.student:
      return _inArea(location, '/student') ? null : Routes.studentHome;
  }
}

bool _inArea(String location, String area) =>
    location == area || location.startsWith('$area/');
