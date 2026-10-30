import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/user.dart';

/// Who receives an announcement: the ids of real, ACTIVE logins only.
///
/// * a student without a login is never a recipient (no one to notify);
/// * suspended accounts and the sender are excluded;
/// * `selectedCircles` = the active students with a login in those circles,
///   plus those circles' teachers;
/// * `selectedUsers` = exactly the chosen ids that are active members.
Set<String> resolveAudience({
  required AudienceType audience,
  required List<String> targetIds,
  required String senderId,
  required Iterable<User> users,
  required Iterable<Student> students,
  required Iterable<Circle> circles,
}) {
  final active = {
    for (final u in users)
      if (u.status == AccountStatus.active) u.uid: u
  };
  Set<String> ids;
  switch (audience) {
    case AudienceType.all:
      ids = active.keys.toSet();
    case AudienceType.teachers:
      ids = {
        for (final u in active.values)
          if (u.role == UserRole.teacher) u.uid
      };
    case AudienceType.studentsWithAccount:
      ids = {
        for (final u in active.values)
          if (u.role == UserRole.student) u.uid
      };
    case AudienceType.selectedCircles:
      final wanted = targetIds.toSet();
      ids = {
        for (final s in students)
          if (s.enrollmentStatus == EnrollmentStatus.active &&
              s.authUserId != null &&
              wanted.contains(s.currentCircleId))
            s.authUserId!,
        for (final c in circles)
          if (wanted.contains(c.circleId) && c.assignedTeacherId != null)
            c.assignedTeacherId!,
      };
    case AudienceType.selectedUsers:
      ids = targetIds.toSet();
  }
  return ids.where((id) => id != senderId && active.containsKey(id)).toSet();
}

String audienceLabel(AudienceType a) {
  switch (a) {
    case AudienceType.all:
      return 'الجميع';
    case AudienceType.teachers:
      return 'المعلمون';
    case AudienceType.studentsWithAccount:
      return 'الطلاب أصحاب الحسابات';
    case AudienceType.selectedCircles:
      return 'حلقات محددة';
    case AudienceType.selectedUsers:
      return 'مستخدمون محددون';
  }
}
