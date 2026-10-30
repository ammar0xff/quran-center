import 'package:quran_center/core/utils/audience.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/notification.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/user.dart';

class NotificationException implements Exception {
  NotificationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A notification document body for [recipientUserId]. Titles and messages are
/// generic by design: no student detail goes into a notification.
Map<String, dynamic> notificationDoc({
  required String centerId,
  required String recipientUserId,
  required String type,
  required String title,
  required String message,
  String? relatedEntityType,
  String? relatedEntityId,
  required DateTime now,
}) =>
    {
      'recipientUserId': recipientUserId,
      'centerId': centerId,
      'type': type,
      'title': title,
      'message': message,
      if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      'read': false,
      'createdAt': firestoreConverter.timestampOf(now),
    };

/// Unique per notification, so sending never overwrites an earlier one.
String newNotificationId(DateTime now, String recipientUserId, [String tag = 'n']) =>
    '${tag}_${now.microsecondsSinceEpoch}_$recipientUserId';

/// The signed-in user's inbox, and the director's announcement publishing.
///
/// Push delivery (FCM) is not wired: notifications are delivered in the app.
class NotificationService {
  NotificationService(this._ds, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  /// One Firestore batch holds 500 writes: the announcement, the audit entry
  /// and one notification per recipient must all fit, atomically.
  static const maxRecipients = 450;

  Future<List<Notification>> inbox(String centerId, String uid) async {
    final docs = await _ds.query('notifications', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('recipientUserId', uid),
    ]);
    return docs
        .map((d) => Notification.fromJson(d['id'] ?? '', firestoreConverter.decodeFromRead(d)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> markRead(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 450) {
      final now = firestoreConverter.timestampOf(_now());
      await _ds.commitBatch([
        for (final id in list.sublist(i, (i + 450).clamp(0, list.length)))
          BatchOp.update('notifications/$id', {'read': true, 'readAt': now}),
      ]);
    }
  }

  /// Publishes an announcement now: the announcement, one notification for
  /// each recipient, and the audit entry are written in ONE batch, so it is
  /// either fully sent or not at all. Returns the number of recipients.
  Future<int> publishAnnouncement({
    required String centerId,
    required String senderId,
    required String senderRole,
    required String announcementId,
    required String title,
    required String message,
    required AudienceType audience,
    List<String> targetIds = const [],
    required List<User> users,
    required List<Student> students,
    required List<Circle> circles,
  }) async {
    final t = title.trim();
    final m = message.trim();
    if (t.isEmpty) throw NotificationException('العنوان مطلوب.');
    if (m.isEmpty) throw NotificationException('نص الإعلان مطلوب.');
    if (t.length > 120) throw NotificationException('العنوان طويل جدًا (الحد 120 حرفًا).');
    if (m.length > 2000) throw NotificationException('النص طويل جدًا (الحد 2000 حرف).');
    if ((audience == AudienceType.selectedCircles || audience == AudienceType.selectedUsers) &&
        targetIds.isEmpty) {
      throw NotificationException('اختر الجهة المستهدفة.');
    }

    final recipients = resolveAudience(
      audience: audience,
      targetIds: targetIds,
      senderId: senderId,
      users: users,
      students: students,
      circles: circles,
    );
    if (recipients.isEmpty) {
      throw NotificationException('لا يوجد مستلمون لهذا الإعلان (لا حسابات مفعّلة في هذه الجهة).');
    }
    if (recipients.length > maxRecipients) {
      throw NotificationException(
          'عدد المستلمين (${recipients.length}) أكبر من الحد ($maxRecipients). اختر حلقات محددة.');
    }

    final now = _now();
    await _ds.commitBatch([
      BatchOp.set('announcements/$announcementId', {
        'centerId': centerId,
        'title': t,
        'message': m,
        'targetAudience': audience.toJson(),
        'targetEntityIds': targetIds,
        'authorId': senderId,
        'status': AnnouncementStatus.published.toJson(),
        'recipientCount': recipients.length,
        'createdAt': firestoreConverter.timestampOf(now),
        'updatedAt': firestoreConverter.timestampOf(now),
      }),
      for (final uid in recipients)
        BatchOp.set(
          'notifications/${newNotificationId(now, uid, 'ann')}',
          notificationDoc(
            centerId: centerId,
            recipientUserId: uid,
            type: 'center_announcement',
            title: t,
            message: m,
            relatedEntityType: 'announcement',
            relatedEntityId: announcementId,
            now: now,
          ),
        ),
      BatchOp.set('audit_logs/aud_${now.microsecondsSinceEpoch}_$announcementId', {
        'centerId': centerId,
        'actorUserId': senderId,
        'actorRole': senderRole,
        'action': 'publish_announcement',
        'entityType': 'announcement',
        'entityId': announcementId,
        'newValue': {'audience': audience.toJson(), 'recipients': recipients.length},
        'createdAt': now.millisecondsSinceEpoch,
      }),
    ]);
    return recipients.length;
  }

  Future<List<Map<String, dynamic>>> announcements(String centerId) async {
    final docs = await _ds.query('announcements', where: [QueryFilter.equal('centerId', centerId)]);
    docs.sort((a, b) {
      final x = firestoreConverter.decodeFromRead(a)['createdAt'];
      final y = firestoreConverter.decodeFromRead(b)['createdAt'];
      return (y is DateTime && x is DateTime) ? y.compareTo(x) : 0;
    });
    return docs.map((d) => firestoreConverter.decodeFromRead(d)..['id'] = d['id']).toList();
  }
}
