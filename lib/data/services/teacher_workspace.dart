import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';

/// Read-only queries for a teacher's own work area.
///
/// Each query is scoped to the center AND to the teacher, which is what the
/// Security Rules need to be able to allow a list query for a teacher.
class TeacherWorkspace {
  TeacherWorkspace(this._ds);

  final FirestoreDataSource _ds;

  Future<List<Schedule>> sessions(String centerId, String teacherId) async {
    final docs = await _ds.query('schedules', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
    ]);
    return docs
        .map((d) => Schedule.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  Future<List<Circle>> circles(String centerId, String teacherId) async {
    final docs = await _ds.query('circles', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('assignedTeacherId', teacherId),
    ]);
    return docs
        .map((d) => Circle.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  Future<List<Student>> students(String centerId, String teacherId) async {
    final docs = await _ds.query('students', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.arrayContains('assignedTeacherIds', teacherId),
    ]);
    return docs
        .map((d) => Student.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }

  Future<List<Enrollment>> activeEnrollments(String centerId, String teacherId) async {
    final docs = await _ds.query('enrollments', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
      QueryFilter.equal('status', 'active'),
    ]);
    return docs
        .map((d) => Enrollment.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
