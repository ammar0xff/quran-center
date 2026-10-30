import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/sync/outbox.dart';
import 'package:quran_center/core/sync/prefs_outbox_storage.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/session_work.dart';

final outboxStorageProvider =
    Provider<OutboxStorage>((ref) => SharedPrefsOutboxStorage());

/// Fires whenever the device's connectivity changes. Tests replace it.
final connectivityEventsProvider = Provider<Stream<void>>((ref) {
  try {
    return Connectivity().onConnectivityChanged.map((_) {});
  } catch (_) {
    return const Stream.empty();
  }
});

/// The signed-in teacher's in-session work queue. Created per user (a queue
/// belongs to one account), loaded from disk, and flushed on start and every
/// time the connection changes.
final sessionWorkProvider = Provider<SessionWork>((ref) {
  final uid = ref.watch(currentSessionProvider.select((s) => s.profile?.uid));
  if (uid == null)
    throw StateError('No signed-in user, so there is no outbox.');
  final work = SessionWork.forOwner(
    ref.watch(teacherSessionServiceProvider),
    ref.watch(outboxStorageProvider),
    uid,
  );
  final sub =
      ref.watch(connectivityEventsProvider).listen((_) => work.outbox.flush());
  ref.onDispose(() {
    sub.cancel();
    work.outbox.dispose();
  });
  unawaited(work.outbox.load().then((_) => work.outbox.flush()));
  return work;
});

/// The queue's state, for indicators.
final outboxSnapshotProvider =
    StreamProvider.autoDispose<OutboxSnapshot>((ref) async* {
  final box = ref.watch(sessionWorkProvider).outbox;
  await box.load();
  yield box.snapshot;
  yield* box.changes;
});
