import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/core/utils/audience.dart';
import 'package:quran_center/data/models/circle.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/models/student.dart';
import 'package:quran_center/data/models/user.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/notification_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

class _AnnouncementData {
  const _AnnouncementData(this.sent, this.users, this.students, this.circles);
  final List<Map<String, dynamic>> sent;
  final List<User> users;
  final List<Student> students;
  final List<Circle> circles;
}

final _announcementDataProvider =
    FutureProvider.autoDispose<_AnnouncementData>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final (sent, users, students, circles) = await (
    ref.read(notificationServiceProvider).announcements(centerId),
    ref.read(userRepositoryProvider).getAllUsersByCenter(centerId),
    ref.read(studentRepositoryProvider).getStudentsByCenter(centerId),
    ref.read(circleRepositoryProvider).getCirclesByCenter(centerId),
  ).wait;
  return _AnnouncementData(sent, users, students, circles);
});

/// Announcements already sent, and a form to send a new one. An announcement
/// goes out immediately, as an in-app notification to each real login in the
/// chosen audience; students without a login are never counted as reached.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_announcementDataProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('الإعلانات'), centerTitle: false),
        floatingActionButton: async.hasValue
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final sent =
                      await Navigator.of(context).push<bool>(MaterialPageRoute(
                    builder: (_) => _ComposeScreen(data: async.requireValue),
                  ));
                  if (sent == true) ref.invalidate(_announcementDataProvider);
                },
                icon: const Icon(Icons.campaign),
                label: const Text('إعلان جديد'),
              )
            : null,
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعذر تحميل الإعلانات'),
              const SizedBox(height: DesignTokens.space12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(_announcementDataProvider),
                  child: const Text('إعادة المحاولة')),
            ]),
          ),
          data: (d) => d.sent.isEmpty
              ? EmptyState('لم تُرسل إعلانات بعد.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(DesignTokens.space16,
                      DesignTokens.space16, DesignTokens.space16, 96),
                  children: [
                    for (final a in d.sent)
                      Card(
                        child: ListTile(
                          title: Text(a['title'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            a['message'] as String,
                            '${audienceLabel(AudienceTypeJson.fromJson(a['targetAudience'] as String?))}'
                                ' • وصل إلى ${a['recipientCount'] ?? 0}',
                            if (a['createdAt'] is DateTime)
                              DateFormat.yMMMd('ar')
                                  .add_jm()
                                  .format(a['createdAt'] as DateTime),
                          ].join('\n')),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                ),
        ),
        bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
      ),
    );
  }
}

class _ComposeScreen extends ConsumerStatefulWidget {
  const _ComposeScreen({required this.data});
  final _AnnouncementData data;

  @override
  ConsumerState<_ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<_ComposeScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  AudienceType _audience = AudienceType.all;
  final Set<String> _circles = {};
  bool _sending = false;
  bool _sent = false;
  String? _error;

  // Fixed per form so a retried send rewrites the same announcement.
  final String _id = 'ann_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _reach => resolveAudience(
        audience: _audience,
        targetIds: _circles.toList(),
        senderId: ref.read(actorProvider).id,
        users: widget.data.users,
        students: widget.data.students,
        circles: widget.data.circles,
      ).length;

  Future<void> _send() async {
    if (_sending || _sent) return;
    final actor = ref.read(actorProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final n = await ref.read(notificationServiceProvider).publishAnnouncement(
            centerId: ref.read(centerIdProvider),
            senderId: actor.id,
            senderRole: actor.role,
            announcementId: _id,
            title: _title.text,
            message: _message.text,
            audience: _audience,
            targetIds: _circles.toList(),
            users: widget.data.users,
            students: widget.data.students,
            circles: widget.data.circles,
          );
      if (!mounted) return;
      _sent = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('أُرسل الإعلان إلى $n مستلم'),
          backgroundColor: DesignTokens.success));
      Navigator.of(context).pop(true);
    } on NotificationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'تعذر إرسال الإعلان. لم يُرسل شيء، حاول مرة أخرى.');
    } finally {
      if (mounted && !_sent) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCircles = widget.data.circles
        .where((c) => c.status == CircleStatus.active)
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(title: const Text('إعلان جديد'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.all(DesignTokens.space20),
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'العنوان *'),
            ),
            const SizedBox(height: DesignTokens.space8),
            TextField(
              controller: _message,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'نص الإعلان *'),
            ),
            const SizedBox(height: DesignTokens.space8),
            DropdownButtonFormField<AudienceType>(
              value: _audience,
              decoration: const InputDecoration(labelText: 'إلى'),
              items: [
                for (final a in [
                  AudienceType.all,
                  AudienceType.teachers,
                  AudienceType.studentsWithAccount,
                  AudienceType.selectedCircles,
                ])
                  DropdownMenuItem(value: a, child: Text(audienceLabel(a))),
              ],
              onChanged: (v) => setState(() => _audience = v ?? _audience),
            ),
            if (_audience == AudienceType.selectedCircles) ...[
              const SizedBox(height: DesignTokens.space12),
              Wrap(
                spacing: DesignTokens.space8,
                children: [
                  for (final c in activeCircles)
                    FilterChip(
                      label: Text(c.name),
                      selected: _circles.contains(c.circleId),
                      onSelected: (on) => setState(() => on
                          ? _circles.add(c.circleId)
                          : _circles.remove(c.circleId)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: DesignTokens.space12),
            Text('سيصل إلى $_reach مستلم',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Text(
                'الطلاب بلا حساب لا يصلهم إشعار إلكتروني ولا يُحسبون هنا.',
                style:
                    TextStyle(fontSize: 12, color: DesignTokens.secondaryText)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.space12),
                child: Text(_error!,
                    style: const TextStyle(color: DesignTokens.error)),
              ),
            const SizedBox(height: DesignTokens.space24),
            SizedBox(
              height: DesignTokens.buttonHeight,
              child: FilledButton(
                onPressed: (_sending || _sent) ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
