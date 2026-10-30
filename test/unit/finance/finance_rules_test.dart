import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/finance/finance_rules.dart';
import 'package:quran_center/core/finance/money.dart';

void main() {
  group('parseAmount', () {
    test('plain, decimal, grouped and Arabic-digit input become exact minor units', () {
      expect(parseAmount('150'), 15000);
      expect(parseAmount('150.5'), 15050);
      expect(parseAmount('150.05'), 15005);
      expect(parseAmount(' 1,250 '), 125000);
      expect(parseAmount('١٥٠٫٥٠'), 15050);
      expect(parseAmount('0.01'), 1);
    });
    test('anything else is refused', () {
      for (final bad in ['', ' ', 'abc', '-5', '1.234', '1..2', '1e3', '12 ج', '100000001', '0', '0.00']) {
        expect(parseAmount(bad), isNull, reason: bad);
      }
      expect(parseAmount('0', allowZero: true), 0);
    });
    test('0.1 + 0.2 style sums stay exact', () {
      expect(parseAmount('0.10')! + parseAmount('0.20')!, parseAmount('0.30'));
    });
  });

  test('formatAmount groups thousands and drops empty decimals', () {
    expect(formatAmount(125000), '1,250 $currencyLabel');
    expect(formatAmount(125050), '1,250.50 $currencyLabel');
    expect(formatAmount(5), '0.05 $currencyLabel');
    expect(formatAmount(0), '0 $currencyLabel');
    expect(formatAmount(-2500), '-25 $currencyLabel');
    expect(formatAmount(100000000), '1,000,000 $currencyLabel');
  });

  test('month keys', () {
    expect(monthKey(DateTime(2026, 3, 9)), '2026-03');
    expect(isMonthKey('2026-12'), isTrue);
    for (final bad in ['2026-13', '2026-00', '26-01', '2026-1', '']) {
      expect(isMonthKey(bad), isFalse, reason: bad);
    }
    expect(nextMonthStart('2026-12'), DateTime(2027, 1));
    expect(monthLabel('2026-11'), 'نوفمبر 2026');
  });

  group('subscription state', () {
    test('by what has been paid', () {
      expect(subscriptionState(due: 100, paid: 0), SubscriptionState.unpaid);
      expect(subscriptionState(due: 100, paid: 40), SubscriptionState.partial);
      expect(subscriptionState(due: 100, paid: 100), SubscriptionState.paid);
      expect(subscriptionState(due: 100, paid: 150), SubscriptionState.overpaid);
      expect(subscriptionState(due: 100, paid: 0, waived: true), SubscriptionState.waived);
    });
    test('outstanding is never negative and a waived one owes nothing', () {
      expect(outstanding(due: 100, paid: 40), 60);
      expect(outstanding(due: 100, paid: 150), 0);
      expect(outstanding(due: 100, paid: 0, waived: true), 0);
    });
    test('every state and method has its own label', () {
      expect(SubscriptionState.values.map(subscriptionStateLabel).toSet(), hasLength(5));
      expect(PaymentMethod.values.map(paymentMethodLabel).toSet(), hasLength(3));
      expect(paymentMethodFrom('bogus'), PaymentMethod.other);
    });
  });

  group('month summary', () {
    final nov = DateTime(2026, 11, 10);
    final oct = DateTime(2026, 10, 20);
    MonthSummary run({
      List<SubscriptionRec>? subs,
      List<PaymentRec>? pays,
      List<ExpenseRec>? exps,
      List<WageRec>? wages,
    }) =>
        summarize('2026-11',
            subscriptions: subs ?? const [],
            payments: pays ?? const [],
            expenses: exps ?? const [],
            wages: wages ?? const []);

    test('an empty month is all zeros', () {
      final s = run();
      expect([s.charged, s.collected, s.expenses, s.wagesPaid, s.wagesDue, s.outstandingTotal, s.net],
          [0, 0, 0, 0, 0, 0, 0]);
    });

    test('charged and outstanding come from the month\'s subscriptions; waived ones are not charged', () {
      final s = run(subs: const [
        SubscriptionRec(month: '2026-11', due: 10000, paid: 4000),
        SubscriptionRec(month: '2026-11', due: 10000, paid: 10000),
        SubscriptionRec(month: '2026-11', due: 10000, paid: 0, waived: true),
        SubscriptionRec(month: '2026-10', due: 99999, paid: 0), // another month
      ]);
      expect(s.charged, 20000);
      expect(s.outstandingTotal, 6000);
    });

    test('collected counts payments RECEIVED in the month, voided ones excluded', () {
      final s = run(pays: [
        PaymentRec(at: nov, amount: 5000),
        PaymentRec(at: nov, amount: 700, voided: true),
        PaymentRec(at: oct, amount: 9000), // paid last month (even if for this month)
        PaymentRec(at: DateTime(2026, 12, 1), amount: 1), // first instant of next month: outside
      ]);
      expect(s.collected, 5000);
    });

    test('expenses by category, voided excluded; wages paid vs still due', () {
      final s = run(
        pays: [PaymentRec(at: nov, amount: 30000)],
        exps: [
          ExpenseRec(date: nov, amount: 4000, category: 'rent'),
          ExpenseRec(date: nov, amount: 1000, category: 'rent'),
          ExpenseRec(date: nov, amount: 500, category: 'supplies'),
          ExpenseRec(date: nov, amount: 8000, category: 'rent', voided: true),
          ExpenseRec(date: oct, amount: 7000, category: 'rent'),
        ],
        wages: [
          WageRec(month: '2026-11', amount: 6000, paid: true, paidAt: nov),
          WageRec(month: '2026-11', amount: 3000, paid: false),
          WageRec(month: '2026-10', amount: 2000, paid: true, paidAt: nov), // October wage paid in November
          WageRec(month: '2026-10', amount: 9000, paid: false), // old debt: not this month's "due"
        ],
      );
      expect(s.expenses, 5500);
      expect(s.expensesByCategory, {'rent': 5000, 'supplies': 500});
      expect(s.wagesPaid, 8000);
      expect(s.wagesDue, 3000);
      expect(s.net, 30000 - 5500 - 8000);
    });
  });
}
