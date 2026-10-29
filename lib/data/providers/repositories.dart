import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/repositories/attendance_repository.dart';
import 'package:quran_center/data/repositories/audit_repository.dart';
import 'package:quran_center/data/repositories/circle_repository.dart';
import 'package:quran_center/data/repositories/enrollment_repository.dart';
import 'package:quran_center/data/repositories/impl/attendance_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/audit_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/circle_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/enrollment_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/schedule_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/student_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/teacher_repository_impl.dart';
import 'package:quran_center/data/repositories/schedule_repository.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/data/repositories/student_repository.dart';
import 'package:quran_center/data/repositories/teacher_repository.dart';

/// One shared in-memory datasource for the whole app until Firebase is
/// configured (flutterfire configure). All repositories read and write the
/// same store, so data created on one screen is visible on the others.
/// Swap this single provider for [FirebaseFirestoreDataSource] to go live.
final firestoreDataSourceProvider = Provider<FakeFirestoreDataSource>(
  (ref) => FakeFirestoreDataSource(),
);

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => StudentRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => TeacherRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => CircleRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) => EnrollmentRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
);

/// Backend-backed digital-access operations. Intentionally has no in-memory
/// default: fabricating logins locally would be a fake credential flow.
/// Without a configured Firebase project the calls fail with a clear message.
final accountAccessServiceProvider = Provider<AccountAccessService>(
  (ref) => CloudFunctionsAccountAccessService(),
);

/// The authenticated user performing an audited action.
class Actor {
  const Actor(this.id, this.role);
  final String id;
  final String role;
}

/// Resolves the acting user from Firebase Auth. Falls back to 'unresolved'
/// when no session exists (or Firebase is not initialised, e.g. in tests);
/// override in tests. The role is a placeholder until role resolution from
/// the authoritative users/{uid} profile is wired.
final actorProvider = Provider<Actor>((ref) {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Actor(uid ?? 'unresolved', 'director');
  } catch (_) {
    return const Actor('unresolved', 'director');
  }
});
