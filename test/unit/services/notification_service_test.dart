import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/services/notification_service.dart';

final _t = DateTime(2026);
final _now = DateTime(2026, 11, 10, 9);

User _u(String id, UserRole role, {AccountStatus status = AccountStatus.active}) => User(
    uid: id, centerId: 'c1', fullName: id, role: role, status: status,
    authProvider: 'password', createdAt: _t, updatedAt: _t);

Student _s(String id, String login, String circle) => Student(
    studentId: id, centerId: 'c1', fullName: id, enrollmentStatus: EnrollmentStatus.active,
    accountMode: AccountMode.loginEnabled, authUserId: login, currentCircleId: circle,
    educationalLevel: 'x', createdAt: _t, updatedAt: _t);

Circle _c(String id, String teacher) => Circle(
    circleId: id, centerId: 'c1', name: id, educationalLevel: 'x', assignedTeacherId: teacher,
    maxCapacity: 5, locationOrMode: 'onsite', weeklySchedule: const [],
    sessionDurationMinutes: 60, status: CircleStatus.active, createdAt: _t, updatedAt: _t);

void main() {
  late FakeFirestoreDataSource store;
  late NotificationService svc;
  final users = [
    _u('dir', UserRole.director), _u('t1', UserRole.teacher), _u('t2', UserRole.teacher),
    _u('u1', UserRole.student), _u('u2', UserRole.student),
  ];
  final students = [_s('s1', 'u1', 'cA'), _s('s2', 'u2', 'cB')];
  final circles = [_c('cA', 't1'), _c('cB', 't2')];

  setUp(() {
    store = FakeFirestoreDataSource();
    svc = NotificationService(store, clock: () => _now);
  });

  Future<int> publish({
    String title = 'اجتماع',
    String message = 'غدًا بعد الفجر',
    AudienceType audience = AudienceType.all,
    List<String> ids = const [],
    List<User>? usersOverride,
  }) =>
      svc.publishAnnouncement(
        centerId: 'c1', senderId: 'dir', senderRole: 'director', announcementId: 'ann1',
        title: title, message: message, audience: audience, targetIds: ids,
        users: usersOverride ?? users, students: students, circles: circles,
      );

  test('publishing writes the announcement, one notification per recipient, and an audit entry', () async {
    expect(await publish(), 4);
    final ann = (await store.getDoc('announcements/ann1'))!;
    expect(ann['status'], 'published');
    expect(ann['recipientCount'], 4);
    expect(ann['authorId'], 'dir');
    final notes = await store.query('notifications', where: []);
    expect(notes.map((n) => n['recipientUserId']).toSet(), {'t1', 't2', 'u1', 'u2'});
    expect(notes.every((n) => n['read'] == false && n['type'] == 'center_announcement'), isTrue);
    expect(notes.every((n) => n['relatedEntityId'] == 'ann1'), isTrue);
    final audit = (await store.query('audit_logs', where: [])).single;
    expect(audit['action'], 'publish_announcement');
    expect((audit['newValue'] as Map)['recipients'], 4);
  });

  test('a circle announcement reaches only that circle\'s students and teacher', () async {
    expect(await publish(audience: AudienceType.selectedCircles, ids: ['cA']), 2);
    final ids = (await store.query('notifications', where: [])).map((n) => n['recipientUserId']).toSet();
    expect(ids, {'u1', 't1'});
  });

  test('empty text, over-long text, no target, or nobody to reach are refused with nothing written', () async {
    await expectLater(publish(title: '  '), throwsA(isA<NotificationException>()));
    await expectLater(publish(message: ''), throwsA(isA<NotificationException>()));
    await expectLater(publish(title: 'ع' * 121), throwsA(isA<NotificationException>()));
    await expectLater(publish(message: 'ن' * 2001), throwsA(isA<NotificationException>()));
    await expectLater(publish(audience: AudienceType.selectedCircles), throwsA(isA<NotificationException>()));
    await expectLater(publish(audience: AudienceType.selectedCircles, ids: ['nope']), throwsA(isA<NotificationException>()));
    expect(await store.getDoc('announcements/ann1'), isNull);
    expect(await store.query('notifications', where: []), isEmpty);
  });

  test('too many recipients for one atomic batch is refused rather than half-sent', () async {
    final many = [
      for (var i = 0; i < NotificationService.maxRecipients + 1; i++) _u('x$i', UserRole.student)
    ];
    await expectLater(publish(usersOverride: many), throwsA(isA<NotificationException>()));
    expect(await store.query('notifications', where: []), isEmpty);
  });

  test('a failed write sends nothing at all', () async {
    final broken = _Broken();
    final s = NotificationService(broken, clock: () => _now);
    await expectLater(
      s.publishAnnouncement(
        centerId: 'c1', senderId: 'dir', senderRole: 'director', announcementId: 'a',
        title: 't', message: 'm', audience: AudienceType.all,
        users: users, students: students, circles: circles,
      ),
      throwsStateError,
    );
    expect(await broken.query('notifications', where: []), isEmpty);
    expect(await broken.getDoc('announcements/a'), isNull);
  });

  group('inbox', () {
    setUp(() async {
      await publish();
    });

    test('lists only my notifications, newest first', () async {
      await store.setDoc('notifications/old', {
        'recipientUserId': 'u1', 'centerId': 'c1', 'type': 'x', 'title': 'قديم', 'message': 'm',
        'read': false, 'createdAt': 1000,
      });
      final mine = await svc.inbox('c1', 'u1');
      expect(mine.map((n) => n.recipientUserId).toSet(), {'u1'});
      expect(mine.first.title, 'اجتماع');
      expect(mine.last.title, 'قديم');
    });

    test('marking read changes only the read flag', () async {
      final n = (await svc.inbox('c1', 'u1')).single;
      await svc.markRead([n.notificationId]);
      final stored = (await store.getDoc('notifications/${n.notificationId}'))!;
      expect(stored['read'], true);
      expect(stored['readAt'], isNotNull);
      expect(stored['title'], 'اجتماع');
      expect((await svc.inbox('c1', 'u1')).single.read, isTrue);
      expect((await svc.inbox('c1', 't1')).single.read, isFalse); // others untouched
    });
  });
}

class _Broken extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async => throw StateError('down');
}
