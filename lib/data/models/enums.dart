/// Shared enumerations for the Quran center domain.
///
/// All enums use explicit, documented values (never arbitrary strings where a
/// controlled state machine is required). Each enum supports JSON round-trip
/// via [fromJson]/[toJson] helpers.

/// User roles. Backend-authoritative — never trusted from the client.
enum UserRole {
  director,
  teacher,
  student,
  guardian, // reserved for future release
}

extension UserRoleJson on UserRole {
  String toJson() => toString().split('.').last;

  static UserRole fromJson(String? json) {
    switch (json) {
      case 'director':
        return UserRole.director;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'guardian':
        return UserRole.guardian;
      default:
        throw ArgumentError('Unknown UserRole: $json');
    }
  }
}

/// Authorization status of a user account.
enum AccountStatus {
  active,
  suspended,
  pending,
  incomplete,
}

extension AccountStatusJson on AccountStatus {
  String toJson() => toString().split('.').last;

  static AccountStatus fromJson(String? json) {
    switch (json) {
      case 'active':
        return AccountStatus.active;
      case 'suspended':
        return AccountStatus.suspended;
      case 'pending':
        return AccountStatus.pending;
      case 'incomplete':
        return AccountStatus.incomplete;
      default:
        throw ArgumentError('Unknown AccountStatus: $json');
    }
  }
}

/// Student digital-access mode. `none` means accountless (no login).
enum AccountMode {
  none,
  loginEnabled,
  suspended,
}

extension AccountModeJson on AccountMode {
  String toJson() => toString().split('.').last;

  static AccountMode fromJson(String? json) {
    switch (json) {
      case 'none':
        return AccountMode.none;
      case 'loginEnabled':
        return AccountMode.loginEnabled;
      case 'suspended':
        return AccountMode.suspended;
      default:
        throw ArgumentError('Unknown AccountMode: $json');
    }
  }
}

/// Enrollment lifecycle status. History is preserved; archival never deletes.
enum EnrollmentStatus {
  active,
  completed,
  transferred,
  withdrawn,
  archived,
}

extension EnrollmentStatusJson on EnrollmentStatus {
  String toJson() => toString().split('.').last;

  static EnrollmentStatus fromJson(String? json) {
    switch (json) {
      case 'active':
        return EnrollmentStatus.active;
      case 'completed':
        return EnrollmentStatus.completed;
      case 'transferred':
        return EnrollmentStatus.transferred;
      case 'withdrawn':
        return EnrollmentStatus.withdrawn;
      case 'archived':
        return EnrollmentStatus.archived;
      default:
        throw ArgumentError('Unknown EnrollmentStatus: $json');
    }
  }
}

/// Attendance statuses. One record per student per session.
enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusJson on AttendanceStatus {
  String toJson() => toString().split('.').last;

  static AttendanceStatus fromJson(String? json) {
    switch (json) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        throw ArgumentError('Unknown AttendanceStatus: $json');
    }
  }
}

/// Memorization / assessment type.
enum AssessmentType {
  /// ورد الحفظ: reciting what was memorised since last time.
  newMemorization,

  /// المراجعة: ماضي قريب.
  recentRevision,

  /// المراجعة: ماضي بعيد.
  longTermRevision,
  generalRecitation,

  /// الجديد: what the student takes to memorise next. Not graded.
  newAssignment,
}

extension AssessmentTypeJson on AssessmentType {
  String toJson() => toString().split('.').last;

  static AssessmentType fromJson(String? json) {
    switch (json) {
      case 'newMemorization':
        return AssessmentType.newMemorization;
      case 'recentRevision':
        return AssessmentType.recentRevision;
      case 'longTermRevision':
        return AssessmentType.longTermRevision;
      case 'generalRecitation':
        return AssessmentType.generalRecitation;
      case 'newAssignment':
        return AssessmentType.newAssignment;
      default:
        throw ArgumentError('Unknown AssessmentType: $json');
    }
  }
}

/// Learning task status machine. Documented valid transitions.
enum TaskStatus {
  upcoming,
  inProgress,
  practiceReported,
  submittedForReview,
  completed,
  needsReview,
  overdue,
  cancelled,
}

extension TaskStatusJson on TaskStatus {
  String toJson() => toString().split('.').last;

  static TaskStatus fromJson(String? json) {
    switch (json) {
      case 'upcoming':
        return TaskStatus.upcoming;
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'practiceReported':
        return TaskStatus.practiceReported;
      case 'submittedForReview':
        return TaskStatus.submittedForReview;
      case 'completed':
        return TaskStatus.completed;
      case 'needsReview':
        return TaskStatus.needsReview;
      case 'overdue':
        return TaskStatus.overdue;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        throw ArgumentError('Unknown TaskStatus: $json');
    }
  }
}

/// Teaching session status. Valid transitions enforced by domain rules.
enum SessionStatus { scheduled, inProgress, completed, cancelled }

extension SessionStatusJson on SessionStatus {
  String toJson() => toString().split('.').last;

  static SessionStatus fromJson(String? json) {
    switch (json) {
      case 'scheduled':
        return SessionStatus.scheduled;
      case 'inProgress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      default:
        throw ArgumentError('Unknown SessionStatus: $json');
    }
  }
}

/// Circle status.
enum CircleStatus { active, archived }

extension CircleStatusJson on CircleStatus {
  String toJson() => toString().split('.').last;

  static CircleStatus fromJson(String? json) {
    switch (json) {
      case 'active':
        return CircleStatus.active;
      case 'archived':
        return CircleStatus.archived;
      default:
        throw ArgumentError('Unknown CircleStatus: $json');
    }
  }
}

/// Announcement publication status.
enum AnnouncementStatus { draft, scheduled, published, archived }

extension AnnouncementStatusJson on AnnouncementStatus {
  String toJson() => toString().split('.').last;

  static AnnouncementStatus fromJson(String? json) {
    switch (json) {
      case 'draft':
        return AnnouncementStatus.draft;
      case 'scheduled':
        return AnnouncementStatus.scheduled;
      case 'published':
        return AnnouncementStatus.published;
      case 'archived':
        return AnnouncementStatus.archived;
      default:
        throw ArgumentError('Unknown AnnouncementStatus: $json');
    }
  }
}

/// Announcement target audience.
enum AudienceType {
  all,
  teachers,
  studentsWithAccount,
  selectedCircles,
  selectedUsers,
}

extension AudienceTypeJson on AudienceType {
  String toJson() => toString().split('.').last;

  static AudienceType fromJson(String? json) {
    switch (json) {
      case 'all':
        return AudienceType.all;
      case 'teachers':
        return AudienceType.teachers;
      case 'studentsWithAccount':
        return AudienceType.studentsWithAccount;
      case 'selectedCircles':
        return AudienceType.selectedCircles;
      case 'selectedUsers':
        return AudienceType.selectedUsers;
      default:
        throw ArgumentError('Unknown AudienceType: $json');
    }
  }
}

/// Task type (mirrors assessment types for task creation).
enum TaskType {
  newMemorization,
  recentRevision,
  longTermRevision,
  generalRecitation,
}

extension TaskTypeJson on TaskType {
  String toJson() => toString().split('.').last;

  static TaskType fromJson(String? json) {
    switch (json) {
      case 'newMemorization':
        return TaskType.newMemorization;
      case 'recentRevision':
        return TaskType.recentRevision;
      case 'longTermRevision':
        return TaskType.longTermRevision;
      case 'generalRecitation':
        return TaskType.generalRecitation;
      default:
        throw ArgumentError('Unknown TaskType: $json');
    }
  }
}

/// Learning plan status.
enum PlanStatus { active, completed, cancelled, archived }

extension PlanStatusJson on PlanStatus {
  String toJson() => toString().split('.').last;

  static PlanStatus fromJson(String? json) {
    switch (json) {
      case 'active':
        return PlanStatus.active;
      case 'completed':
        return PlanStatus.completed;
      case 'cancelled':
        return PlanStatus.cancelled;
      case 'archived':
        return PlanStatus.archived;
      default:
        throw ArgumentError('Unknown PlanStatus: $json');
    }
  }
}

/// Task type alias for learning tasks (uses TaskType directly).

/// The mark a teacher gives to ONE wird (what a student recited).
/// ممتاز / جيد جدًا / جيد / مقبول / إعادة.
enum WirdGrade { excellent, veryGood, good, acceptable, repeat }

extension WirdGradeJson on WirdGrade {
  String toJson() => toString().split('.').last;

  static WirdGrade fromJson(String? json) {
    switch (json) {
      case 'excellent':
        return WirdGrade.excellent;
      case 'veryGood':
        return WirdGrade.veryGood;
      case 'good':
        return WirdGrade.good;
      case 'acceptable':
        return WirdGrade.acceptable;
      case 'repeat':
        return WirdGrade.repeat;
      default:
        throw ArgumentError('Unknown WirdGrade: $json');
    }
  }

  /// 5 (ممتاز) down to 1 (إعادة). Used only to summarise a level.
  int get score => switch (this) {
        WirdGrade.excellent => 5,
        WirdGrade.veryGood => 4,
        WirdGrade.good => 3,
        WirdGrade.acceptable => 2,
        WirdGrade.repeat => 1,
      };

  String get label => switch (this) {
        WirdGrade.excellent => 'ممتاز',
        WirdGrade.veryGood => 'جيد جدًا',
        WirdGrade.good => 'جيد',
        WirdGrade.acceptable => 'مقبول',
        WirdGrade.repeat => 'إعادة',
      };
}
