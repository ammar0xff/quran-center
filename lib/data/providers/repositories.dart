import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/repositories/impl/student_repository_impl.dart';
import 'package:quran_center/data/repositories/student_repository.dart';

/// Student repository provider — backed by an in-memory fake datasource.
///
/// Swap to [FirebaseFirestoreDataSource] (from firestore_datasource.dart)
/// once a real Firebase project is configured via flutterfire configure.
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final fake = FakeFirestoreDataSource();
  return StudentRepositoryImpl(fake);
});
