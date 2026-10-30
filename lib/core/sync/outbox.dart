import 'dart:async';
import 'dart:convert';

/// A change made by the user that still has to reach the server.
///
/// [key] is the idempotency key: queueing a second change with the same key
/// REPLACES the first (the newest intent wins), and replaying the same key can
/// never create a second record because the handler writes to a deterministic
/// id. [type] picks the handler.
class OutboxOp {
  OutboxOp({
    required this.key,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.scope,
    this.attempts = 0,
    this.error,
  });

  final String key;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Groups related changes (for example a session id).
  final String? scope;
  final int attempts;

  /// Set when the server (or a rule) REJECTED the change. It will not be
  /// retried automatically: the user decides to retry or discard it.
  final String? error;

  bool get failed => error != null;

  OutboxOp copyWith({int? attempts, String? error, bool clearError = false}) =>
      OutboxOp(
        key: key,
        type: type,
        payload: payload,
        createdAt: createdAt,
        scope: scope,
        attempts: attempts ?? this.attempts,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (scope != null) 'scope': scope,
        'attempts': attempts,
        if (error != null) 'error': error,
      };

  factory OutboxOp.fromJson(Map<String, dynamic> j) => OutboxOp(
        key: j['key'] as String,
        type: j['type'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        scope: j['scope'] as String?,
        attempts: (j['attempts'] as int?) ?? 0,
        error: j['error'] as String?,
      );
}

/// Thrown by a handler when the change can never succeed as written (the
/// session has ended, a rule refused it, ...). Anything else a handler throws
/// is treated as temporary (no network, timeout) and retried later.
class PermanentOutboxFailure implements Exception {
  PermanentOutboxFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef OutboxHandler = Future<void> Function(OutboxOp op);

/// Where the queue is kept between app launches.
abstract class OutboxStorage {
  Future<String?> read(String owner);
  Future<void> write(String owner, String json);
}

class MemoryOutboxStorage implements OutboxStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(String owner) async => data[owner];
  @override
  Future<void> write(String owner, String json) async => data[owner] = json;
}

class OutboxSnapshot {
  const OutboxSnapshot(this.ops, {this.syncing = false});
  final List<OutboxOp> ops;
  final bool syncing;

  int get pending => ops.where((o) => !o.failed).length;
  int get failed => ops.where((o) => o.failed).length;
  bool get isEmpty => ops.isEmpty;
  Iterable<OutboxOp> inScope(String scope) =>
      ops.where((o) => o.scope == scope);
}

/// A durable, ordered queue of changes for ONE owner (one signed-in user).
///
/// * survives restarts (persisted after every change);
/// * same key replaces the earlier change (newest wins) and keeps its place;
/// * flushed oldest first; a temporary failure stops the run and keeps
///   everything for later, a permanent failure marks just that change and the
///   run carries on;
/// * only one flush runs at a time.
class Outbox {
  Outbox({
    required this.owner,
    required this.storage,
    required Map<String, OutboxHandler> handlers,
    this.attemptTimeout = const Duration(seconds: 15),
  }) : _handlers = handlers;

  final String owner;
  final OutboxStorage storage;
  final Map<String, OutboxHandler> _handlers;
  final Duration attemptTimeout;

  final _ops = <OutboxOp>[];
  final _changes = StreamController<OutboxSnapshot>.broadcast();
  bool _loaded = false;
  bool _flushing = false;
  bool _flushAgain = false;

  Stream<OutboxSnapshot> get changes => _changes.stream;
  OutboxSnapshot get snapshot =>
      OutboxSnapshot(List.unmodifiable(_ops), syncing: _flushing);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await storage.read(owner);
    if (raw != null && raw.isNotEmpty) {
      try {
        _ops.addAll((jsonDecode(raw) as List).map(
            (e) => OutboxOp.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {
        // A corrupt queue must not brick the app; start empty.
      }
    }
    _emit();
  }

  Future<void> _persist() =>
      storage.write(owner, jsonEncode(_ops.map((o) => o.toJson()).toList()));

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  /// Queues [op]. A queued change with the same key is replaced in place.
  Future<void> enqueue(OutboxOp op) async {
    await load();
    final i = _ops.indexWhere((o) => o.key == op.key);
    if (i >= 0) {
      _ops[i] = op;
    } else {
      _ops.add(op);
    }
    await _persist();
    _emit();
  }

  /// Sends everything that is waiting. Safe to call at any time.
  Future<void> flush() async {
    await load();
    if (_flushing) {
      _flushAgain = true; // pick up anything queued during this run
      return;
    }
    _flushing = true;
    _emit();
    try {
      do {
        _flushAgain = false;
        await _runOnce();
      } while (_flushAgain);
    } finally {
      _flushing = false;
      _emit();
    }
  }

  Future<void> _runOnce() async {
    for (final queued in List<OutboxOp>.of(_ops)) {
      if (queued.failed) continue;
      // The op may have been replaced while an earlier one was sending.
      final current = _ops.where((o) => o.key == queued.key).firstOrNull;
      if (current == null || current.failed) continue;
      final handler = _handlers[current.type];
      if (handler == null) {
        await _replace(current, current.copyWith(error: 'نوع تغيير غير معروف'));
        continue;
      }
      try {
        await handler(current).timeout(attemptTimeout);
        // Only drop it if it was not replaced by a newer intent meanwhile.
        final latest = _ops.where((o) => o.key == current.key).firstOrNull;
        if (latest != null && identical(latest, current)) {
          _ops.removeWhere((o) => o.key == current.key);
          await _persist();
          _emit();
        } else if (latest != null) {
          _flushAgain =
              true; // a newer intent arrived while this one was sending
        }
      } on PermanentOutboxFailure catch (e) {
        await _replace(current,
            current.copyWith(attempts: current.attempts + 1, error: e.message));
      } catch (_) {
        // Temporary (offline, timeout, server busy): keep it and stop here so
        // the order of later changes is preserved.
        await _replace(
            current, current.copyWith(attempts: current.attempts + 1));
        return;
      }
    }
  }

  Future<void> _replace(OutboxOp old, OutboxOp updated) async {
    final i = _ops.indexWhere((o) => o.key == old.key);
    if (i >= 0 && identical(_ops[i], old)) _ops[i] = updated;
    await _persist();
    _emit();
  }

  /// Gives rejected changes another try.
  Future<void> retryFailed() async {
    await load();
    for (var i = 0; i < _ops.length; i++) {
      if (_ops[i].failed) _ops[i] = _ops[i].copyWith(clearError: true);
    }
    await _persist();
    _emit();
    await flush();
  }

  /// Drops one change the user does not want to retry.
  Future<void> discard(String key) async {
    await load();
    _ops.removeWhere((o) => o.key == key);
    await _persist();
    _emit();
  }

  Future<void> dispose() => _changes.close();
}
