import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';

/// Actions a director can take on a student's digital access.
enum AccessAction { enable, suspend, reactivate }

/// Why an action is not allowed (null reason = allowed).
enum AccessBlock {
  alreadyHasLogin,
  noLoginToChange,
  notSuspended,
  alreadySuspended,
  archivedStudent,
  missingLink,
}

/// Decides whether [action] may be started for [student].
///
/// State machine (mirrored by the `enableStudentAccess` /
/// `setStudentAccessSuspended` Cloud Functions, which are authoritative):
///
///   none ──enable──▶ loginEnabled ──suspend──▶ suspended
///                         ▲                       │
///                         └──────reactivate───────┘
///
/// * Enabling is only valid for accountless students (no existing link), so a
///   second account can never be attached to the same student.
/// * Suspend / reactivate require an existing linked account.
/// * Archived students cannot be given new access.
AccessBlock? checkAccessAction(Student student, AccessAction action) {
  switch (action) {
    case AccessAction.enable:
      if (student.enrollmentStatus == EnrollmentStatus.archived) {
        return AccessBlock.archivedStudent;
      }
      if (student.accountMode != AccountMode.none ||
          student.authUserId != null) {
        return AccessBlock.alreadyHasLogin;
      }
      return null;
    case AccessAction.suspend:
      if (student.accountMode == AccountMode.suspended) {
        return AccessBlock.alreadySuspended;
      }
      if (student.accountMode != AccountMode.loginEnabled) {
        return AccessBlock.noLoginToChange;
      }
      if (student.authUserId == null) return AccessBlock.missingLink;
      return null;
    case AccessAction.reactivate:
      if (student.accountMode != AccountMode.suspended) {
        return AccessBlock.notSuspended;
      }
      if (student.authUserId == null) return AccessBlock.missingLink;
      return null;
  }
}

/// Basic email shape check used before calling the backend.
bool isPlausibleEmail(String value) {
  final v = value.trim();
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v);
}
