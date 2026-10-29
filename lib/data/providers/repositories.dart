import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/repositories/impl/circle_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/enrollment_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/student_repository_impl.dart';
import 'package:quran_center/data/repositories/impl/teacher_repository_impl.dart';
import 'package:quran_center/data/repositories/circle_repository.dart';
import 'package:quran_center/data/repositories/enrollment_repository.dart';
import 'package:quran_center/data/repositories/student_repository.dart';
import 'package:quran_center/data/repositories/teacher_repository.dart';

/// Student repository provider — backed by an in-memory fake datasource.
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final fake = FakeFirestoreDataSource();
  return StudentRepositoryImpl(fake);
});

/// Teacher repository provider — backed by an in-memory fake datasource.
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final fake = FakeFirestoreDataSource();
  return TeacherRepositoryImpl(fake);
});

/// Circle repository provider — backed by an in-memory fake datasource.
final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  final fake = FakeFirestoreDataSource();
  return CircleRepositoryImpl(fake);
});

/// Enrollment repository provider — backed by an in-memory fake datasource.
final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  final fake = FakeFirestoreDataSource();
  return EnrollmentRepositoryImpl(fake);
});
