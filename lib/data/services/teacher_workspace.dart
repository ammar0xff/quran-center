import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enrollment.dart';
import 'package:quran_center/data/models/memorization_record.dart';
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

  /// This teacher's assessments of one student, newest first.
  Future<List<MemorizationRecord>> assessments(
      String centerId, String teacherId, String studentId) async {
    final docs = await _ds.query('memorization_records', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
      QueryFilter.equal('studentId', studentId),
    ]);
    final list = docs
        .map((d) => MemorizationRecord.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
    list.sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
    return list;
  }

  /// The teacher's private notes about one student, keyed by assessment id.
  Future<Map<String, String>> privateNotes(
      String centerId, String teacherId, String studentId) async {
    final docs = await _ds.query('private_teacher_notes', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('teacherId', teacherId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return {for (final d in docs) d['id'] as String: (d['note'] ?? '') as String};
  }

  /// Attendance this teacher recorded for one student.
  Future<List<Attendance>> attendance(
      String centerId, String teacherId, String studentId) async {
    final docs = await _ds.query('attendance', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('recordedBy', teacherId),
      QueryFilter.equal('studentId', studentId),
    ]);
    return docs
        .map((d) => Attendance.fromJson(
            d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList();
  }
}
