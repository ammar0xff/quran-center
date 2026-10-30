import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/notification.dart' as model;
import 'package:quran_center/data/providers/repositories.dart';

/// The signed-in user's notifications. Only ever the user's own.
final inboxProvider =
    FutureProvider.autoDispose<List<model.Notification>>((ref) async {
  final profile = ref.watch(currentSessionProvider).profile;
  if (profile == null) return [];
  return ref
      .read(notificationServiceProvider)
      .inbox(profile.centerId, profile.uid);
});

/// A bell with the number of unread notifications; opens [route].
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.route, this.onDark = false});

  final String route;

  /// White icon, for use on the emerald header.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(inboxProvider).valueOrNull?.where((n) => !n.read).length ?? 0;
    return IconButton(
      tooltip: unread == 0 ? 'الإشعارات' : 'الإشعارات ($unread غير مقروء)',
      onPressed: () async {
        await context.push(route);
        ref.invalidate(inboxProvider);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: Icon(Icons.notifications_outlined,
            color: onDark ? Colors.white : null),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.bottomNavigationBar});

  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inboxProvider);
    final unreadIds = async.valueOrNull
            ?.where((n) => !n.read)
            .map((n) => n.notificationId)
            .toList() ??
        [];

    Future<void> markAll() async {
      try {
        await ref.read(notificationServiceProvider).markRead(unreadIds);
        ref.invalidate(inboxProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تعذر التحديث. حاول مرة أخرى.'),
              backgroundColor: DesignTokens.error));
        }
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: QAppBar(
          title: const Text('الإشعارات'),
          centerTitle: false,
          actions: [
            if (unreadIds.isNotEmpty)
              TextButton(
                  onPressed: markAll, child: const Text('تعليم الكل كمقروء')),
          ],
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعذر تحميل الإشعارات'),
              const SizedBox(height: DesignTokens.space12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(inboxProvider),
                  child: const Text('إعادة المحاولة')),
            ]),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState('لا توجد إشعارات.');
            }
            return ListView(
              padding: const EdgeInsets.all(DesignTokens.space12),
              children: [
                for (final n in items)
                  Card(
                    color: n.read ? null : DesignTokens.softMint,
                    child: ListTile(
                      leading: Icon(
                          n.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: DesignTokens.primaryDarkGreen),
                      title: Text(n.title,
                          style: TextStyle(
                              fontWeight:
                                  n.read ? FontWeight.w500 : FontWeight.w700)),
                      subtitle: Text(
                          '${n.message}\n${DateFormat.yMMMd('ar').add_jm().format(n.createdAt)}'),
                      isThreeLine: true,
                      onTap: n.read
                          ? null
                          : () async {
                              await ref
                                  .read(notificationServiceProvider)
                                  .markRead([n.notificationId]);
                              ref.invalidate(inboxProvider);
                            },
                    ),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
