import 'package:quran_center/data/models/app_model.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/schedule.dart';

/// Why a teaching-session action is not allowed right now.
enum SessionBlock {
  notToday,
  cancelled,
  completed,
  alreadyStarted,
  notStarted,
}

/// A session can be started only on its own day, and only once.
SessionBlock? checkStart(Schedule s, DateTime now) {
  switch (s.status) {
    case SessionStatus.cancelled:
      return SessionBlock.cancelled;
    case SessionStatus.completed:
      return SessionBlock.completed;
    case SessionStatus.inProgress:
      return SessionBlock.alreadyStarted;
    case SessionStatus.scheduled:
      return s.date.isSameDate(now) ? null : SessionBlock.notToday;
  }
}

/// Attendance can be recorded (and fixed by the teacher) only while the
/// session is in progress. Afterwards only a director's audited correction
/// changes it.
SessionBlock? checkRecord(Schedule s) {
  switch (s.status) {
    case SessionStatus.inProgress:
      return null;
    case SessionStatus.scheduled:
      return SessionBlock.notStarted;
    case SessionStatus.completed:
      return SessionBlock.completed;
    case SessionStatus.cancelled:
      return SessionBlock.cancelled;
  }
}

/// Only a session in progress can be completed.
SessionBlock? checkComplete(Schedule s) => checkRecord(s);

String sessionBlockMessage(SessionBlock b) {
  switch (b) {
    case SessionBlock.notToday:
      return 'يمكن بدء الجلسة في يومها فقط.';
    case SessionBlock.cancelled:
      return 'هذه الجلسة ملغاة.';
    case SessionBlock.completed:
      return 'انتهت هذه الجلسة. تعديل الحضور بعد انتهائها يتم عبر الإدارة.';
    case SessionBlock.alreadyStarted:
      return 'الجلسة بدأت بالفعل.';
    case SessionBlock.notStarted:
      return 'ابدأ الجلسة أولًا.';
  }
}
