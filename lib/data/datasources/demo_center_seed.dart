import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/models/enums.dart';

/// Pre-populated realistic demo center data ("دار النور النموذجية").
/// Used by the interactive 3-in-1 demo mode so directors can experience the entire
/// platform across all three roles before activating their subscription.
class DemoCenterSeed {
  static const centerId = 'demo-center';
  static const centerName = 'دار النور لتحفيظ القرآن';

  // Demo user profiles
  static final directorUser = User(
    uid: 'demo-director',
    fullName: 'أم عبدالله (مديرة الدار)',
    role: UserRole.director,
    centerId: centerId,
    status: AccountStatus.active,
    authProvider: 'password',
    phone: '01000000000',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
    updatedAt: DateTime.now(),
  );

  static final teacherUser = User(
    uid: 'demo-teacher',
    fullName: 'المعلمة فاطمة الزهراء',
    role: UserRole.teacher,
    centerId: centerId,
    status: AccountStatus.active,
    authProvider: 'password',
    phone: '01000000001',
    createdAt: DateTime.now().subtract(const Duration(days: 60)),
    updatedAt: DateTime.now(),
  );

  static final studentUser = User(
    uid: 'demo-student',
    fullName: 'بسمة خالد',
    role: UserRole.student,
    centerId: centerId,
    studentId: 'stu-1',
    status: AccountStatus.active,
    authProvider: 'password',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now(),
  );

  /// Seeds a [FakeFirestoreDataSource] with complete, realistic demo records.
  static FakeFirestoreDataSource createSeededDataSource() {
    final ds = FakeFirestoreDataSource();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // 1. Center
    ds.setDoc('centers/$centerId', {
      'id': centerId,
      'name': centerName,
      'slug': 'alnoor',
      'currency': 'EGP',
      'subscription': {
        'status': 'demo',
        'plan': 'starter',
      },
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // 2. Users
    ds.setDoc('users/${directorUser.uid}', directorUser.toJson());
    ds.setDoc('users/${teacherUser.uid}', teacherUser.toJson());
    ds.setDoc('users/${studentUser.uid}', studentUser.toJson());

    // 3. Teachers
    ds.setDoc('teachers/${teacherUser.uid}', {
      'id': teacherUser.uid,
      'fullName': teacherUser.fullName,
      'email': 'fatima@alnoor.meshkah',
      'phone': '01000000001',
      'centerId': centerId,
      'assignedCircleIds': ['circle-fajr'],
      'status': 'active',
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // 4. Circles
    ds.setDoc('circles/circle-fajr', {
      'id': 'circle-fajr',
      'centerId': centerId,
      'name': 'حلقة الفجر (تجويد وحفظ)',
      'educationalLevel': 'متوسط',
      'assignedTeacherId': teacherUser.uid,
      'maxCapacity': 10,
      'activeCount': 3,
      'locationOrMode': 'onsite',
      'sessionDurationMinutes': 60,
      'status': 'active',
      'weeklySchedule': [
        {'dayOfWeek': 6, 'startTime': '05:30', 'endTime': '06:30'},
        {'dayOfWeek': 1, 'startTime': '05:30', 'endTime': '06:30'},
        {'dayOfWeek': 3, 'startTime': '05:30', 'endTime': '06:30'},
      ],
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    ds.setDoc('circles/circle-maghrib', {
      'id': 'circle-maghrib',
      'centerId': centerId,
      'name': 'حلقة المغرب (تأسيس ومبتدئ)',
      'educationalLevel': 'مبتدئ',
      'assignedTeacherId': null,
      'maxCapacity': 12,
      'activeCount': 0,
      'locationOrMode': 'onsite',
      'sessionDurationMinutes': 45,
      'status': 'active',
      'weeklySchedule': [],
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // 5. Students
    final students = [
      {'id': 'stu-1', 'name': 'بسمة خالد', 'level': 'متوسط', 'mode': 'loginEnabled', 'auth': studentUser.uid},
      {'id': 'stu-2', 'name': 'أحمد علي', 'level': 'متوسط', 'mode': 'none', 'auth': null},
      {'id': 'stu-3', 'name': 'مريم سعيد', 'level': 'مبتدئ', 'mode': 'none', 'auth': null},
    ];

    for (final s in students) {
      final sid = s['id'] as String;
      ds.setDoc('students/$sid', {
        'id': sid,
        'centerId': centerId,
        'fullName': s['name'],
        'educationalLevel': s['level'],
        'enrollmentStatus': 'active',
        'accountMode': s['mode'],
        'authUserId': s['auth'],
        'assignedTeacherIds': [teacherUser.uid],
        'currentCircleId': 'circle-fajr',
        'createdAt': nowMs - 30 * 86400000,
        'updatedAt': nowMs,
      });

      ds.setDoc('student_directory/$sid', {
        'id': sid,
        'centerId': centerId,
        'fullName': s['name'],
        'active': true,
      });

      ds.setDoc('student_fees/$sid', {
        'id': sid,
        'centerId': centerId,
        'studentId': sid,
        'monthlyFee': 25000, // 250 EGP (in cents)
      });

      ds.setDoc('enrollments/enr_${sid}_fajr', {
        'id': 'enr_${sid}_fajr',
        'centerId': centerId,
        'studentId': sid,
        'circleId': 'circle-fajr',
        'teacherId': teacherUser.uid,
        'startDate': nowMs - 30 * 86400000,
        'status': 'active',
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });
    }

    // 6. Learning plan for stu-1
    ds.setDoc('learning_plans/plan_stu-1', {
      'id': 'plan_stu-1',
      'centerId': centerId,
      'studentId': 'stu-1',
      'responsibleTeacherId': teacherUser.uid,
      'educationalObjective': 'حفظ جزء عم وإتقان أحكام النون الساكنة',
      'startDate': nowMs - 20 * 86400000,
      'targetDate': nowMs + 40 * 86400000,
      'status': 'active',
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // 7. Learning tasks
    ds.setDoc('learning_tasks/task-1', {
      'id': 'task-1',
      'centerId': centerId,
      'planId': 'plan_stu-1',
      'studentId': 'stu-1',
      'teacherId': teacherUser.uid,
      'taskType': 'newMemorization',
      'surah': 78, // النبأ
      'startAyah': 1,
      'endAyah': 16,
      'assignedDate': nowMs - 2 * 86400000,
      'dueDate': nowMs + 1 * 86400000,
      'teacherInstructions': 'تكرار الآيات مع الاستماع للشيخ الحصري',
      'status': 'inProgress',
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    ds.setDoc('learning_tasks/task-2', {
      'id': 'task-2',
      'centerId': centerId,
      'planId': 'plan_stu-1',
      'studentId': 'stu-1',
      'teacherId': teacherUser.uid,
      'taskType': 'recentRevision',
      'surah': 79, // النازعات
      'startAyah': 1,
      'endAyah': 20,
      'assignedDate': nowMs - 5 * 86400000,
      'dueDate': nowMs + 3 * 86400000,
      'teacherInstructions': 'مراجعة متأنية مع مراعاة الغنن',
      'status': 'upcoming',
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // 8. Schedules and Attendance
    ds.setDoc('schedules/sess-today', {
      'id': 'sess-today',
      'centerId': centerId,
      'circleId': 'circle-fajr',
      'teacherId': teacherUser.uid,
      'date': nowMs,
      'startTime': '05:30',
      'endTime': '06:30',
      'locationOrMode': 'onsite',
      'status': 'scheduled',
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    ds.setDoc('schedules/sess-prev', {
      'id': 'sess-prev',
      'centerId': centerId,
      'circleId': 'circle-fajr',
      'teacherId': teacherUser.uid,
      'date': nowMs - 2 * 86400000,
      'startTime': '05:30',
      'endTime': '06:30',
      'locationOrMode': 'onsite',
      'status': 'completed',
      'createdAt': nowMs - 2 * 86400000,
      'updatedAt': nowMs - 2 * 86400000,
    });

    ds.setDoc('attendance/sess-prev_stu-1', {
      'id': 'sess-prev_stu-1',
      'centerId': centerId,
      'sessionId': 'sess-prev',
      'studentId': 'stu-1',
      'status': 'present',
      'recordedBy': teacherUser.uid,
      'createdAt': nowMs - 2 * 86400000,
      'updatedAt': nowMs - 2 * 86400000,
    });

    // 9. Memorization Assessment
    ds.setDoc('memorization_records/rec-1', {
      'id': 'rec-1',
      'centerId': centerId,
      'studentId': 'stu-1',
      'teacherId': teacherUser.uid,
      'sessionId': 'sess-prev',
      'circleId': 'circle-fajr',
      'assessmentType': 'newMemorization',
      'grade': 'excellent',
      'schemaVersion': 1,
      'surah': 78,
      'startAyah': 1,
      'endAyah': 16,
      'studentFeedback': 'ممتازة يا بسمة! قراءة متقنة ومخارج حروف واضحة.',
      'createdAt': nowMs - 2 * 86400000,
      'updatedAt': nowMs - 2 * 86400000,
    });

    // 10. Financial Transactions (Demo)
    ds.setDoc('finance_transactions/tx-1', {
      'id': 'tx-1',
      'centerId': centerId,
      'type': 'subscriptionPayment',
      'amount': 25000,
      'studentId': 'stu-1',
      'title': 'اشتراك شهر ربيع الأول - بسمة خالد',
      'date': nowMs - 5 * 86400000,
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    return ds;
  }
}
