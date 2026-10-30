import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
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
import 'package:quran_center/data/repositories/impl/user_repository_impl.dart';
import 'package:quran_center/data/repositories/schedule_repository.dart';
import 'package:quran_center/data/services/circle_service.dart';
import 'package:quran_center/data/services/enrollment_service.dart';
import 'package:quran_center/data/services/notification_service.dart';
import 'package:quran_center/data/services/student_workspace.dart';
import 'package:quran_center/data/services/task_service.dart';
import 'package:quran_center/data/services/teacher_session_service.dart';
import 'package:quran_center/data/services/teacher_workspace.dart';
import 'package:quran_center/data/repositories/user_repository.dart';
import 'package:quran_center/data/services/account_access_service.dart';
import 'package:quran_center/data/repositories/student_repository.dart';
import 'package:quran_center/data/repositories/teacher_repository.dart';

/// The one data source every repository and service reads and writes: the real
/// Firestore. Tests override this single provider with the in-memory fake.
final firestoreDataSourceProvider = Provider<FirestoreDataSource>(
  (ref) => FirebaseFirestoreDataSource(FirebaseFirestore.instance),
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

final teacherSessionServiceProvider = Provider<TeacherSessionService>(
  (ref) => TeacherSessionService(ref.watch(firestoreDataSourceProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(firestoreDataSourceProvider)),
);

final studentWorkspaceProvider = Provider<StudentWorkspace>(
  (ref) => StudentWorkspace(ref.watch(firestoreDataSourceProvider)),
);

final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(ref.watch(firestoreDataSourceProvider)),
);

final teacherWorkspaceProvider = Provider<TeacherWorkspace>(
  (ref) => TeacherWorkspace(ref.watch(firestoreDataSourceProvider)),
);

final circleServiceProvider = Provider<CircleService>(
  (ref) => CircleService(ref.watch(firestoreDataSourceProvider)),
);

final enrollmentServiceProvider = Provider<EnrollmentService>(
  (ref) => EnrollmentService(ref.watch(firestoreDataSourceProvider)),
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

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(ref.watch(firestoreDataSourceProvider)),
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

