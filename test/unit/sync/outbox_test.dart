import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/sync/outbox.dart';

OutboxOp _op(String key, {String type = 't', Map<String, dynamic>? payload, String? scope}) =>
    OutboxOp(key: key, type: type, payload: payload ?? {'k': key}, createdAt: DateTime(2026), scope: scope);

void main() {
  late MemoryOutboxStorage storage;
  late List<String> sent;
  late Object? Function(OutboxOp op) behaviour;

  Outbox make({String owner = 'u1', Duration timeout = const Duration(seconds: 5)}) => Outbox(
        owner: owner,
        storage: storage,
        attemptTimeout: timeout,
        handlers: {
          't': (op) async {
            final r = behaviour(op);
            if (r is Exception) throw r;
            sent.add('${op.key}:${op.payload['v'] ?? ''}');
          },
        },
      );

  setUp(() {
    storage = MemoryOutboxStorage();
    sent = [];
    behaviour = (_) => null;
  });

  test('changes are sent oldest first and the queue empties', () async {
    final box = make();
    await box.enqueue(_op('a', payload: {'v': 1}));
    await box.enqueue(_op('b', payload: {'v': 2}));
    await box.flush();
    expect(sent, ['a:1', 'b:2']);
    expect(box.snapshot.isEmpty, isTrue);
  });

  test('the same key replaces the earlier change and keeps its place (newest wins)', () async {
    final box = make();
    await box.enqueue(_op('a', payload: {'v': 1}));
    await box.enqueue(_op('b', payload: {'v': 2}));
    await box.enqueue(_op('a', payload: {'v': 3}));
    expect(box.snapshot.ops.map((o) => o.key), ['a', 'b']);
    await box.flush();
    expect(sent, ['a:3', 'b:2']);
  });

  test('a temporary failure keeps everything, in order, and counts the attempt', () async {
    final box = make();
    await box.enqueue(_op('a'));
    await box.enqueue(_op('b'));
    behaviour = (_) => Exception('offline');
    await box.flush();
    expect(sent, isEmpty);
    expect(box.snapshot.pending, 2);
    expect(box.snapshot.failed, 0);
    expect(box.snapshot.ops.first.attempts, 1);
    expect(box.snapshot.ops.last.attempts, 0); // stopped at the first

    behaviour = (_) => null;
    await box.flush();
    expect(sent, ['a:', 'b:']); // order preserved once back online
    expect(box.snapshot.isEmpty, isTrue);
  });

  test('a rejected change is marked failed with its reason; the others still go', () async {
    final box = make();
    await box.enqueue(_op('bad'));
    await box.enqueue(_op('good'));
    behaviour = (op) => op.key == 'bad' ? PermanentOutboxFailure('انتهت الجلسة') : null;
    await box.flush();
    expect(sent, ['good:']);
    expect(box.snapshot.failed, 1);
    expect(box.snapshot.ops.single.error, 'انتهت الجلسة');
    // A failed change is not retried automatically.
    sent.clear();
    await box.flush();
    expect(sent, isEmpty);
  });

  test('retryFailed gives rejected changes another go; discard removes one', () async {
    final box = make();
    await box.enqueue(_op('bad'));
    behaviour = (_) => PermanentOutboxFailure('x');
    await box.flush();
    behaviour = (_) => null;
    await box.retryFailed();
    expect(sent, ['bad:']);
    expect(box.snapshot.isEmpty, isTrue);

    await box.enqueue(_op('drop'));
    await box.discard('drop');
    await box.flush();
    expect(sent, ['bad:']);
  });

  test('the queue survives a restart, and belongs to its owner only', () async {
    final first = make();
    await first.enqueue(_op('a', payload: {'v': 7}, scope: 's1'));
    behaviour = (_) => Exception('offline');
    await first.flush();

    final restarted = make();
    await restarted.load();
    expect(restarted.snapshot.ops.single.key, 'a');
    expect(restarted.snapshot.ops.single.scope, 's1');
    expect(restarted.snapshot.ops.single.attempts, 1);

    final other = make(owner: 'u2');
    await other.load();
    expect(other.snapshot.isEmpty, isTrue); // another user never sees or sends it
  });

  test('a corrupt stored queue is ignored rather than crashing', () async {
    storage.data['u1'] = '{not json';
    final box = make();
    await box.load();
    expect(box.snapshot.isEmpty, isTrue);
    await box.enqueue(_op('a'));
    await box.flush();
    expect(sent, ['a:']);
  });

  test('a change queued while another is being sent is not lost, and not sent twice', () async {
    final gate = Completer<void>();
    final box = Outbox(
      owner: 'u1',
      storage: storage,
      handlers: {
        't': (op) async {
          if (op.key == 'a') await gate.future;
          sent.add(op.key);
        },
      },
    );
    await box.enqueue(_op('a'));
    final running = box.flush();
    await Future<void>.delayed(Duration.zero);
    await box.enqueue(_op('b'));
    await box.flush(); // second call while the first is running
    gate.complete();
    await running;
    expect(sent, ['a', 'b']);
    expect(box.snapshot.isEmpty, isTrue);
  });

  test('a newer intent queued while the old one is in flight is kept, not dropped', () async {
    final gate = Completer<void>();
    final box = Outbox(
      owner: 'u1',
      storage: storage,
      handlers: {
        't': (op) async {
          sent.add('${op.key}:${op.payload['v']}');
          if (op.payload['v'] == 1) await gate.future;
        },
      },
    );
    await box.enqueue(_op('a', payload: {'v': 1}));
    final running = box.flush();
    await Future<void>.delayed(Duration.zero);
    await box.enqueue(_op('a', payload: {'v': 2})); // user changed their mind
    gate.complete();
    await running;
    expect(sent, ['a:1', 'a:2']); // the latest value still reaches the server
    expect(box.snapshot.isEmpty, isTrue);
  });

  test('a send that hangs is treated as temporary after the timeout', () async {
    final box = Outbox(
      owner: 'u1',
      storage: storage,
      attemptTimeout: const Duration(milliseconds: 20),
      handlers: {'t': (op) => Completer<void>().future},
    );
    await box.enqueue(_op('a'));
    await box.flush();
    expect(box.snapshot.pending, 1);
    expect(box.snapshot.ops.single.attempts, 1);
    expect(box.snapshot.ops.single.failed, isFalse);
  });

  test('an unknown change type is marked failed, not retried forever', () async {
    final box = make();
    await box.enqueue(_op('a', type: 'mystery'));
    await box.flush();
    expect(box.snapshot.failed, 1);
  });

  test('scope filtering', () async {
    final box = make();
    await box.enqueue(_op('a', scope: 's1'));
    await box.enqueue(_op('b', scope: 's2'));
    expect(box.snapshot.inScope('s1').map((o) => o.key), ['a']);
  });
}
