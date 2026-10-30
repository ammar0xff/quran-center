import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/finance/finance_rules.dart';
import 'package:quran_center/data/datasources/fake_firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/services/finance_service.dart';

final _now = DateTime(2026, 11, 10, 9);

Future<void> _seed(FakeFirestoreDataSource s) async {
  Future<void> student(String id, String name, String status, {String center = 'c1'}) =>
      s.setDoc('students/$id', {
        'centerId': center, 'fullName': name, 'enrollmentStatus': status, 'accountMode': 'none',
        'educationalLevel': 'x', 'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await student('s1', 'بسمة', 'active');
  await student('s2', 'أحمد', 'active');
  await student('s3', 'بلا رسوم', 'active');
  await student('s4', 'مؤرشف', 'archived');
  await student('sx', 'مركز آخر', 'active', center: 'c2');
  Future<void> teacher(String id, String name, String status, {String center = 'c1'}) =>
      s.setDoc('teachers/$id', {
        'centerId': center, 'userId': id, 'fullName': name, 'status': status,
        'createdAt': 1700000000000, 'updatedAt': 1700000000000,
      });
  await teacher('t1', 'المعلمة فاطمة', 'active');
  await teacher('t2', 'المعلمة خديجة', 'suspended');
  await teacher('tx', 'مركز آخر', 'active', center: 'c2');
}

void main() {
  late FakeFirestoreDataSource store;
  late FinanceService svc;

  setUp(() async {
    store = FakeFirestoreDataSource();
    await _seed(store);
    svc = FinanceService(store, clock: () => _now);
  });

  Future<void> fee(String s, int cents) =>
      svc.setStudentFee(centerId: 'c1', actorId: 'dir', studentId: s, monthlyFee: cents);
  Future<int> issue([String month = '2026-11']) =>
      svc.issueSubscriptions(centerId: 'c1', actorId: 'dir', month: month);
  Future<void> pay(String id, int amount, {String sub = 's1_2026-11', DateTime? at}) => svc.recordPayment(
      centerId: 'c1', actorId: 'dir', paymentId: id, subscriptionId: sub, amount: amount,
      method: PaymentMethod.cash, paidAt: at);
  Future<int> paidOn(String sub) async => (await store.getDoc('subscriptions/$sub'))!['amountPaid'] as int;
  Future<int> auditCount(String action) async =>
      (await store.query('audit_logs', where: [])).where((a) => a['action'] == action).length;

  group('fees and subscriptions', () {
    test('a fee is set for a student of this center, audited, and a repeat changes nothing', () async {
      await fee('s1', 15000);
      expect((await store.getDoc('student_fees/s1'))!['monthlyFee'], 15000);
      await fee('s1', 15000);
      expect(await auditCount('set_student_fee'), 1);
      await fee('s1', 20000);
      final last = (await store.query('audit_logs', where: [])).last;
      expect(last['previousValue'], {'monthlyFee': 15000});
      await expectLater(fee('sx', 100), throwsA(isA<FinanceException>()));
      await expectLater(fee('ghost', 100), throwsA(isA<FinanceException>()));
      await expectLater(fee('s1', -1), throwsA(isA<FinanceException>()));
    });

    test('the month is issued to active students with a fee only, once', () async {
      await fee('s1', 15000);
      await fee('s2', 10000);
      await fee('s4', 10000); // archived
      expect(await issue(), 2);
      final s1 = (await store.getDoc('subscriptions/s1_2026-11'))!;
      expect([s1['amountDue'], s1['amountPaid'], s1['studentName']], [15000, 0, 'بسمة']);
      expect(await store.getDoc('subscriptions/s3_2026-11'), isNull);
      expect(await store.getDoc('subscriptions/s4_2026-11'), isNull);
      expect(await store.getDoc('subscriptions/sx_2026-11'), isNull);
      expect(await issue(), 0); // repeating adds nothing
      expect(await auditCount('issue_subscriptions'), 1);
    });

    test('re-issuing never resets what was already paid', () async {
      await fee('s1', 15000);
      await issue();
      await pay('p1', 5000);
      await fee('s1', 99999); // fee changes later
      await issue();
      final s1 = (await store.getDoc('subscriptions/s1_2026-11'))!;
      expect([s1['amountDue'], s1['amountPaid']], [15000, 5000]);
    });

    test('a bad month is refused', () async {
      await expectLater(issue('2026-13'), throwsA(isA<FinanceException>()));
    });
  });

  group('payments', () {
    setUp(() async {
      await fee('s1', 15000);
      await issue();
    });

    test('a payment updates the subscription and is audited, in one step', () async {
      await pay('p1', 5000);
      await pay('p2', 10000);
      expect(await paidOn('s1_2026-11'), 15000);
      final p = (await store.getDoc('payments/p1'))!;
      expect([p['amount'], p['studentId'], p['receivedBy'], p['voided'], p['method']], [5000, 's1', 'dir', false, 'cash']);
      expect(await auditCount('record_payment'), 2);
      final data = await svc.load('c1');
      expect(data.subscriptions.single.state, SubscriptionState.paid);
    });

    test('retrying the same payment never counts it twice', () async {
      await pay('p1', 5000);
      await pay('p1', 5000);
      expect(await paidOn('s1_2026-11'), 5000);
      expect(await store.query('payments', where: []), hasLength(1));
    });

    test('over-payment is allowed and shown as such; zero, future and unknown targets are refused', () async {
      await pay('p1', 20000);
      expect((await svc.load('c1')).subscriptions.single.state, SubscriptionState.overpaid);
      await expectLater(pay('p2', 0), throwsA(isA<FinanceException>()));
      await expectLater(pay('p3', 100, at: DateTime(2026, 12, 25)), throwsA(isA<FinanceException>()));
      await expectLater(pay('p4', 100, sub: 'ghost_2026-11'), throwsA(isA<FinanceException>()));
      expect(await paidOn('s1_2026-11'), 20000);
    });

    test('voiding gives the money back to the balance, keeps the record, and cannot repeat', () async {
      await pay('p1', 5000);
      await pay('p2', 4000);
      await svc.voidPayment(centerId: 'c1', actorId: 'dir', paymentId: 'p1', reason: '  خطأ إدخال ');
      expect(await paidOn('s1_2026-11'), 4000);
      final p = (await store.getDoc('payments/p1'))!;
      expect([p['voided'], p['voidReason'], p['voidedBy'], p['amount']], [true, 'خطأ إدخال', 'dir', 5000]);
      await expectLater(svc.voidPayment(centerId: 'c1', actorId: 'dir', paymentId: 'p1', reason: 'x'),
          throwsA(isA<FinanceException>()));
      await expectLater(svc.voidPayment(centerId: 'c1', actorId: 'dir', paymentId: 'p2', reason: ' '),
          throwsA(isA<FinanceException>()));
      expect(await paidOn('s1_2026-11'), 4000);
    });

    test('waiving needs a reason and no payments; a waived subscription takes no payment', () async {
      await fee('s2', 10000);
      await issue();
      await pay('p1', 100);
      await expectLater(svc.waiveSubscription(centerId: 'c1', actorId: 'dir', subscriptionId: 's1_2026-11', reason: 'يتيم'),
          throwsA(isA<FinanceException>())); // has a payment
      await expectLater(svc.waiveSubscription(centerId: 'c1', actorId: 'dir', subscriptionId: 's2_2026-11', reason: ' '),
          throwsA(isA<FinanceException>()));
      await svc.waiveSubscription(centerId: 'c1', actorId: 'dir', subscriptionId: 's2_2026-11', reason: 'يتيم');
      expect((await svc.load('c1')).subscriptions.firstWhere((s) => s.id == 's2_2026-11').state,
          SubscriptionState.waived);
      await expectLater(pay('p9', 100, sub: 's2_2026-11'), throwsA(isA<FinanceException>()));
    });

    test('another center\'s director cannot touch these subscriptions or payments', () async {
      await pay('p1', 1000);
      await expectLater(
          svc.recordPayment(centerId: 'c2', actorId: 'x', paymentId: 'q', subscriptionId: 's1_2026-11',
              amount: 1, method: PaymentMethod.cash),
          throwsA(isA<FinanceException>()));
      await expectLater(svc.voidPayment(centerId: 'c2', actorId: 'x', paymentId: 'p1', reason: 'r'),
          throwsA(isA<FinanceException>()));
      expect(await paidOn('s1_2026-11'), 1000);
    });
  });

  group('expenses', () {
    Future<void> add(String id, {String cat = 'rent', int amount = 100000, DateTime? date}) => svc.addExpense(
        centerId: 'c1', actorId: 'dir', expenseId: id, category: cat, amount: amount,
        date: date ?? _now, description: '  إيجار الشهر ');

    test('recorded with its category, audited, idempotent on retry', () async {
      await add('e1');
      await add('e1');
      final e = (await store.getDoc('expenses/e1'))!;
      expect([e['category'], e['amount'], e['description'], e['recordedBy'], e['voided']],
          ['rent', 100000, 'إيجار الشهر', 'dir', false]);
      expect(await store.query('expenses', where: []), hasLength(1));
      expect(await auditCount('add_expense'), 1);
    });

    test('unknown category, non-positive amount and a future date are refused', () async {
      await expectLater(add('e2', cat: 'bribes'), throwsA(isA<FinanceException>()));
      await expectLater(add('e3', amount: 0), throwsA(isA<FinanceException>()));
      await expectLater(add('e4', date: DateTime(2027, 1, 1)), throwsA(isA<FinanceException>()));
      expect(await store.query('expenses', where: []), isEmpty);
    });

    test('voiding keeps the record and drops it from the totals', () async {
      await add('e1');
      await svc.voidExpense(centerId: 'c1', actorId: 'dir', expenseId: 'e1', reason: 'مكرر');
      expect((await store.getDoc('expenses/e1'))!['voided'], true);
      expect((await svc.load('c1')).summary('2026-11').expenses, 0);
      await expectLater(svc.voidExpense(centerId: 'c1', actorId: 'dir', expenseId: 'e1', reason: 'مرة أخرى'),
          throwsA(isA<FinanceException>()));
      await expectLater(svc.voidExpense(centerId: 'c1', actorId: 'dir', expenseId: 'e1', reason: ''),
          throwsA(isA<FinanceException>()));
    });
  });

  group('teacher wages', () {
    Future<void> rate(String t, int c) =>
        svc.setWageRate(centerId: 'c1', actorId: 'dir', teacherId: t, monthlyAmount: c);
    Future<int> issueW([String m = '2026-11']) => svc.issueWages(centerId: 'c1', actorId: 'dir', month: m);

    test('wages are issued to active teachers with a rate, once per month', () async {
      await rate('t1', 300000);
      await rate('t2', 300000); // suspended
      expect(await issueW(), 1);
      final w = (await store.getDoc('wages/t1_2026-11'))!;
      expect([w['amount'], w['baseAmount'], w['status'], w['teacherName']], [300000, 300000, 'due', 'المعلمة فاطمة']);
      expect(await issueW(), 0);
      await expectLater(rate('tx', 1), throwsA(isA<FinanceException>())); // other center
    });

    test('a bonus or deduction needs a reason, cannot make the wage negative, and is audited', () async {
      await rate('t1', 300000);
      await issueW();
      Future<void> adj(int a, String n) =>
          svc.adjustWage(centerId: 'c1', actorId: 'dir', wageId: 't1_2026-11', adjustment: a, note: n);
      await adj(-20000, 'غياب يومين');
      var w = (await store.getDoc('wages/t1_2026-11'))!;
      expect([w['amount'], w['baseAmount'], w['adjustment']], [280000, 300000, -20000]);
      await adj(50000, 'مكافأة'); // replaces the earlier adjustment, from the base
      expect((await store.getDoc('wages/t1_2026-11'))!['amount'], 350000);
      await expectLater(adj(-400000, 'كثير'), throwsA(isA<FinanceException>()));
      await expectLater(adj(100, ' '), throwsA(isA<FinanceException>()));
      expect(await auditCount('adjust_wage'), 2);
    });

    test('paying marks it paid with who/when/how; then it is frozen', () async {
      await rate('t1', 300000);
      await issueW();
      await svc.payWage(centerId: 'c1', actorId: 'dir', wageId: 't1_2026-11', method: PaymentMethod.transfer);
      final w = (await store.getDoc('wages/t1_2026-11'))!;
      expect([w['status'], w['paidBy'], w['method']], ['paid', 'dir', 'transfer']);
      await expectLater(svc.payWage(centerId: 'c1', actorId: 'dir', wageId: 't1_2026-11', method: PaymentMethod.cash),
          throwsA(isA<FinanceException>()));
      await expectLater(
          svc.adjustWage(centerId: 'c1', actorId: 'dir', wageId: 't1_2026-11', adjustment: 1, note: 'x'),
          throwsA(isA<FinanceException>()));
      await expectLater(svc.payWage(centerId: 'c2', actorId: 'x', wageId: 't1_2026-11', method: PaymentMethod.cash),
          throwsA(isA<FinanceException>()));
    });
  });

  test('the month summary adds it all up from the real records', () async {
    await fee('s1', 15000);
    await fee('s2', 10000);
    await issue();
    await pay('p1', 15000);
    await pay('p2', 4000, sub: 's2_2026-11');
    await svc.addExpense(centerId: 'c1', actorId: 'dir', expenseId: 'e1', category: 'rent', amount: 8000, date: _now);
    await svc.setWageRate(centerId: 'c1', actorId: 'dir', teacherId: 't1', monthlyAmount: 6000);
    await svc.issueWages(centerId: 'c1', actorId: 'dir', month: '2026-11');
    final due = (await svc.load('c1')).summary('2026-11');
    expect([due.charged, due.collected, due.outstandingTotal, due.expenses, due.wagesPaid, due.wagesDue],
        [25000, 19000, 6000, 8000, 0, 6000]);
    await svc.payWage(centerId: 'c1', actorId: 'dir', wageId: 't1_2026-11', method: PaymentMethod.cash);
    final paid = (await svc.load('c1')).summary('2026-11');
    expect([paid.wagesPaid, paid.wagesDue, paid.net], [6000, 0, 19000 - 8000 - 6000]);
  });

  test('a failed write leaves no half-recorded payment', () async {
    final broken = _FailingTx();
    await _seed(broken);
    await broken.setDoc('subscriptions/s1_2026-11', {
      'centerId': 'c1', 'studentId': 's1', 'month': '2026-11', 'amountDue': 100, 'amountPaid': 0,
    });
    final s = FinanceService(broken, clock: () => _now);
    await expectLater(
        s.recordPayment(centerId: 'c1', actorId: 'd', paymentId: 'p', subscriptionId: 's1_2026-11',
            amount: 50, method: PaymentMethod.cash),
        throwsStateError);
    expect(await broken.getDoc('payments/p'), isNull);
    expect((await broken.getDoc('subscriptions/s1_2026-11'))!['amountPaid'], 0);
  });
}

class _FailingTx extends FakeFirestoreDataSource {
  @override
  Future<void> commitBatch(List<BatchOp> ops) async => throw StateError('down');
}
