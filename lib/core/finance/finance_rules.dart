import 'package:quran_center/core/finance/money.dart';

enum SubscriptionState { unpaid, partial, paid, overpaid, waived }

String subscriptionStateLabel(SubscriptionState s) => switch (s) {
      SubscriptionState.unpaid => 'غير مدفوع',
      SubscriptionState.partial => 'مدفوع جزئيًا',
      SubscriptionState.paid => 'مدفوع',
      SubscriptionState.overpaid => 'مدفوع بزيادة',
      SubscriptionState.waived => 'معفى',
    };

SubscriptionState subscriptionState({
  required int due,
  required int paid,
  bool waived = false,
}) {
  if (waived) return SubscriptionState.waived;
  if (paid <= 0) return SubscriptionState.unpaid;
  if (paid < due) return SubscriptionState.partial;
  return paid == due ? SubscriptionState.paid : SubscriptionState.overpaid;
}

/// What is still owed on a subscription (never negative; a waived one owes 0).
int outstanding({required int due, required int paid, bool waived = false}) =>
    waived ? 0 : (due - paid).clamp(0, 1 << 40);

enum PaymentMethod { cash, transfer, other }

String paymentMethodLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'نقدًا',
      PaymentMethod.transfer => 'تحويل',
      PaymentMethod.other => 'أخرى',
    };

PaymentMethod paymentMethodFrom(String? s) => PaymentMethod.values
    .firstWhere((m) => m.name == s, orElse: () => PaymentMethod.other);

const expenseCategories = <String, String>{
  'rent': 'إيجار',
  'utilities': 'مرافق (كهرباء/ماء/إنترنت)',
  'supplies': 'مستلزمات وأدوات',
  'maintenance': 'صيانة',
  'events': 'مناسبات وجوائز',
  'other': 'أخرى',
};

/// One row of the month's money, built from records that are NOT voided.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.charged,
    required this.collected,
    required this.expenses,
    required this.wagesPaid,
    required this.wagesDue,
    required this.outstandingTotal,
    required this.expensesByCategory,
  });

  final String month;

  /// Subscriptions issued for the month.
  final int charged;

  /// Payments RECEIVED in the month (whatever month they pay for).
  final int collected;
  final int expenses;

  /// Wages actually paid in the month / still owed for the month.
  final int wagesPaid;
  final int wagesDue;

  /// Still owed on this month's subscriptions.
  final int outstandingTotal;
  final Map<String, int> expensesByCategory;

  /// Cash view: received minus spent minus wages paid. Money owed to the
  /// center and wages not yet paid are NOT in it.
  int get net => collected - expenses - wagesPaid;
}

class SubscriptionRec {
  const SubscriptionRec(
      {required this.month,
      required this.due,
      required this.paid,
      this.waived = false});
  final String month;
  final int due;
  final int paid;
  final bool waived;
}

class PaymentRec {
  const PaymentRec(
      {required this.at, required this.amount, this.voided = false});
  final DateTime at;
  final int amount;
  final bool voided;
}

class ExpenseRec {
  const ExpenseRec(
      {required this.date,
      required this.amount,
      required this.category,
      this.voided = false});
  final DateTime date;
  final int amount;
  final String category;
  final bool voided;
}

class WageRec {
  const WageRec(
      {required this.month,
      required this.amount,
      required this.paid,
      this.paidAt});
  final String month;
  final int amount;
  final bool paid;
  final DateTime? paidAt;
}

MonthSummary summarize(
  String month, {
  required Iterable<SubscriptionRec> subscriptions,
  required Iterable<PaymentRec> payments,
  required Iterable<ExpenseRec> expenses,
  required Iterable<WageRec> wages,
}) {
  final from = monthStart(month), to = nextMonthStart(month);
  bool inMonth(DateTime d) => !d.isBefore(from) && d.isBefore(to);
  final subs = subscriptions.where((s) => s.month == month);
  final byCat = <String, int>{};
  var exp = 0;
  for (final e in expenses) {
    if (e.voided || !inMonth(e.date)) continue;
    exp += e.amount;
    byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
  }
  return MonthSummary(
    month: month,
    charged: subs.where((s) => !s.waived).fold(0, (a, s) => a + s.due),
    collected: payments
        .where((p) => !p.voided && inMonth(p.at))
        .fold(0, (a, p) => a + p.amount),
    expenses: exp,
    wagesPaid: wages
        .where((w) => w.paid && w.paidAt != null && inMonth(w.paidAt!))
        .fold(0, (a, w) => a + w.amount),
    wagesDue: wages
        .where((w) => w.month == month && !w.paid)
        .fold(0, (a, w) => a + w.amount),
    outstandingTotal: subs.fold(0,
        (a, s) => a + outstanding(due: s.due, paid: s.paid, waived: s.waived)),
    expensesByCategory: byCat,
  );
}
