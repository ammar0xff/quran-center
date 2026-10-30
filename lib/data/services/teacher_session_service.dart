import 'package:quran_center/core/utils/session_rules.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/attendance.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';
import 'package:quran_center/data/models/student.dart';

/// A teaching-session action that cannot proceed. [message] is Arabic.
class SessionException implements Exception {
  SessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SessionRoster {
  const SessionRoster({
    required this.session,
    required this.circleName,
    required this.students,
    required this.records,
  });

  final Schedule session;
  final String? circleName;

  /// The teacher's active students in the session's circle, by name.
  final List<Student> students;

  /// This teacher's attendance records for the session, keyed by student id.
  final Map<String, Attendance> records;

  List<Student> get missing =>
      students.where((s) => !records.containsKey(s.studentId)).toList();
}

/// A teacher's operations on their own teaching sessions.
///
/// Every query carries the center and the teacher, as the Security Rules
/// require. Nothing here trusts the UI: state and ownership are re-checked
/// against the stored session before each write.
class TeacherSessionService {
  TeacherSessionService(this._ds, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  static const _tsKeys = {'createdAt', 'updatedAt', 'startedAt', 'completedAt'};

  /// Sessions of other teachers or centers look the same as missing ones.
  Future<Schedule> _session(String centerId, String teacherId, String sessionId) async {
    final raw = await _ds.getDoc('schedules/$sessionId');
    if (raw == null || raw['centerId'] != centerId || raw['teacherId'] != teacherId) {
      throw SessionException('لم يتم العثور على الجلسة.');
    }
    return Schedule.fromJson(sessionId, firestoreConverter.decodeFromRead(raw));
  }

  Future<void> start({
    required String centerId,
    required String teacherId,
    required String sessionId,
  }) async {
    final s = await _session(centerId, teacherId, sessionId);
    final block = checkStart(s, _now());
    if (block != null) throw SessionException(sessionBlockMessage(block));
    await _ds.updateDoc('schedules/$sessionId', {
      'status': SessionStatus.inProgress.toJson(),
      'startedAt': firestoreConverter.serverTimestamp(),
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  Future<void> complete({
    required String centerId,
    required String teacherId,
    required String sessionId,
  }) async {
    final s = await _session(centerId, teacherId, sessionId);
    final block = checkComplete(s);
    if (block != null) throw SessionException(sessionBlockMessage(block));
    await _ds.updateDoc('schedules/$sessionId', {
      'status': SessionStatus.completed.toJson(),
      'completedAt': firestoreConverter.serverTimestamp(),
      'updatedAt': firestoreConverter.serverTimestamp(),
    });
  }

  Future<SessionRoster> loadRoster({
    required String centerId,
    required String teacherId,
    required String sessionId,
  }) async {
    final session = await _session(centerId, teacherId, sessionId);

    final circleRaw = await _ds.getDoc('circles/${session.circleId}');
    final circleName = circleRaw?['name'] as String?;

    final enrolled = await _ds.query('enrollments', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('circleId', session.circleId),
      QueryFilter.equal('status', 'active'),
      QueryFilter.equal('teacherId', teacherId),
    ]);
    final enrolledIds = {for (final e in enrolled) e['studentId'] as String};

    final students = (await _ds.query('students', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.arrayContains('assignedTeacherIds', teacherId),
    ]))
        .map((d) => Student.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .where((s) => enrolledIds.contains(s.studentId))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final records = await _records(centerId, teacherId, sessionId);
    return SessionRoster(
      session: session,
      circleName: circleName,
      students: students,
      records: records,
    );
  }

  Future<Map<String, Attendance>> _records(
      String centerId, String teacherId, String sessionId,
      {String? studentId}) async {
    final docs = await _ds.query('attendance', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('sessionId', sessionId),
      QueryFilter.equal('recordedBy', teacherId),
      if (studentId != null) QueryFilter.equal('studentId', studentId),
    ]);
    final list = docs.map((d) => Attendance.fromJson(
        d['id'] ?? '', firestoreConverter.decodeFromRead(d)));
    return {for (final a in list) a.studentId: a};
  }

  /// Records (or, while the session is in progress, fixes) one student's
  /// attendance. The document id is `<sessionId>_<studentId>`, so repeating
  /// the call never creates a duplicate.
  Future<void> record({
    required String centerId,
    required String teacherId,
    required String sessionId,
    required String studentId,
    required AttendanceStatus status,
    String? note,
  }) async {
    final session = await _session(centerId, teacherId, sessionId);
    final block = checkRecord(session);
    if (block != null) throw SessionException(sessionBlockMessage(block));

    final inCircle = await _ds.query('enrollments', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('circleId', session.circleId),
      QueryFilter.equal('studentId', studentId),
      QueryFilter.equal('status', 'active'),
      QueryFilter.equal('teacherId', teacherId),
    ]);
    if (inCircle.isEmpty) {
      throw SessionException('هذا الطالب ليس ضمن طلاب هذه الجلسة.');
    }

    final trimmed = note?.trim();
    final cleanNote = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final path = 'attendance/${sessionId}_$studentId';
    final existing = await _records(centerId, teacherId, sessionId, studentId: studentId);

    if (existing.containsKey(studentId)) {
      await _ds.updateDoc(path, {
        'status': status.toJson(),
        'note': cleanNote,
        'updatedAt': firestoreConverter.serverTimestamp(),
      });
    } else {
      final now = _now();
      await _ds.setDoc(
        path,
        firestoreConverter.encodeForWrite(
          Attendance(
            attendanceId: '${sessionId}_$studentId',
            centerId: centerId,
            sessionId: sessionId,
            studentId: studentId,
            status: status,
            recordedBy: teacherId,
            note: cleanNote,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          timestampKeys: _tsKeys,
        ),
      );
    }
  }
}
