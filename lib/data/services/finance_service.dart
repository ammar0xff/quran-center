import 'package:quran_center/core/finance/finance_rules.dart';
import 'package:quran_center/core/finance/money.dart';
import 'package:quran_center/data/datasources/firestore_datasource.dart';
import 'package:quran_center/data/datasources/firestore_helpers.dart';

class FinanceException implements Exception {
  FinanceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Subscription {
  Subscription(this.id, Map<String, dynamic> j)
      : studentId = j['studentId'] as String,
        studentName = (j['studentName'] as String?) ?? '',
        month = j['month'] as String,
        due = j['amountDue'] as int,
        paid = j['amountPaid'] as int,
        waived = (j['waived'] as bool?) ?? false;
  final String id;
  final String studentId;
  final String studentName;
  final String month;
  final int due;
  final int paid;
  final bool waived;

  SubscriptionState get state => subscriptionState(due: due, paid: paid, waived: waived);
  int get owed => outstanding(due: due, paid: paid, waived: waived);
}

class Payment {
  Payment(this.id, Map<String, dynamic> j)
      : subscriptionId = j['subscriptionId'] as String,
        studentId = j['studentId'] as String,
        amount = j['amount'] as int,
        method = paymentMethodFrom(j['method'] as String?),
        note = j['note'] as String?,
        paidAt = (j['paidAt'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0),
        voided = (j['voided'] as bool?) ?? false;
  final String id;
  final String subscriptionId;
  final String studentId;
  final int amount;
  final PaymentMethod method;
  final String? note;
  final DateTime paidAt;
  final bool voided;
}

class Expense {
  Expense(this.id, Map<String, dynamic> j)
      : category = j['category'] as String,
        amount = j['amount'] as int,
        description = (j['description'] as String?) ?? '',
        date = (j['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0),
        voided = (j['voided'] as bool?) ?? false,
        voidReason = j['voidReason'] as String?;
  final String id;
  final String category;
  final int amount;
  final String description;
  final DateTime date;
  final bool voided;
  final String? voidReason;
}

class Wage {
  Wage(this.id, Map<String, dynamic> j)
      : teacherId = j['teacherId'] as String,
        teacherName = (j['teacherName'] as String?) ?? '',
        month = j['month'] as String,
        base = (j['baseAmount'] as int?) ?? (j['amount'] as int),
        adjustment = (j['adjustment'] as int?) ?? 0,
        adjustmentNote = j['adjustmentNote'] as String?,
        amount = j['amount'] as int,
        paid = j['status'] == 'paid',
        paidAt = j['paidAt'] as DateTime?,
        method = paymentMethodFrom(j['method'] as String?);
  final String id;
  final String teacherId;
  final String teacherName;
  final String month;
  final int base;
  final int adjustment;
  final String? adjustmentNote;
  final int amount;
  final bool paid;
  final DateTime? paidAt;
  final PaymentMethod method;
}

class FinanceData {
  const FinanceData({
    required this.fees,
    required this.rates,
    required this.subscriptions,
    required this.payments,
    required this.expenses,
    required this.wages,
  });
  final Map<String, int> fees; // studentId -> monthly fee
  final Map<String, int> rates; // teacherId -> monthly wage
  final List<Subscription> subscriptions;
  final List<Payment> payments;
  final List<Expense> expenses;
  final List<Wage> wages;

  MonthSummary summary(String month) => summarize(
        month,
        subscriptions: [
          for (final s in subscriptions)
            SubscriptionRec(month: s.month, due: s.due, paid: s.paid, waived: s.waived)
        ],
        payments: [for (final p in payments) PaymentRec(at: p.paidAt, amount: p.amount, voided: p.voided)],
        expenses: [
          for (final e in expenses)
            ExpenseRec(date: e.date, amount: e.amount, category: e.category, voided: e.voided)
        ],
        wages: [
          for (final w in wages) WageRec(month: w.month, amount: w.amount, paid: w.paid, paidAt: w.paidAt)
        ],
      );
}

/// The center's money, managed by the director.
///
/// Amounts are whole minor units. Each action is one atomic write together
/// with its audit entry, and a retried action (same id) changes nothing twice.
/// Nothing is deleted: payments and expenses are voided with a reason.
class FinanceService {
  FinanceService(this._ds, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final FirestoreDataSource _ds;
  final DateTime Function() _now;

  Map<String, dynamic> _audit(String centerId, String actorId, String action, String type,
          String id, Map<String, dynamic> newValue, [Map<String, dynamic>? previous]) =>
      {
        'centerId': centerId,
        'actorUserId': actorId,
        'actorRole': 'director',
        'action': action,
        'entityType': type,
        'entityId': id,
        if (previous != null) 'previousValue': previous,
        'newValue': newValue,
        'createdAt': _now().millisecondsSinceEpoch,
      };

  int _seq = 0;

  /// Unique even when two actions fall in the same microsecond.
  String _auditPath(String entity) => 'audit_logs/aud_${_now().microsecondsSinceEpoch}_${_seq++}_$entity';

  Future<List<Map<String, dynamic>>> _all(String collection, String centerId) async =>
      (await _ds.query(collection, where: [QueryFilter.equal('centerId', centerId)]))
          .map((d) => {...firestoreConverter.decodeFromRead(d), 'id': d['id']})
          .toList();

  Future<FinanceData> load(String centerId) async {
    final (fees, rates, subs, pays, exps, wages) = await (
      _all('student_fees', centerId),
      _all('wage_rates', centerId),
      _all('subscriptions', centerId),
      _all('payments', centerId),
      _all('expenses', centerId),
      _all('wages', centerId),
    ).wait;
    return FinanceData(
      fees: {for (final f in fees) f['studentId'] as String: f['monthlyFee'] as int},
      rates: {for (final r in rates) r['teacherId'] as String: r['monthlyAmount'] as int},
      subscriptions: [for (final s in subs) Subscription(s['id'] as String, s)]
        ..sort((a, b) {
          final m = b.month.compareTo(a.month);
          return m != 0 ? m : a.studentName.compareTo(b.studentName);
        }),
      payments: [for (final p in pays) Payment(p['id'] as String, p)]
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt)),
      expenses: [for (final e in exps) Expense(e['id'] as String, e)]
        ..sort((a, b) => b.date.compareTo(a.date)),
      wages: [for (final w in wages) Wage(w['id'] as String, w)]
        ..sort((a, b) {
          final m = b.month.compareTo(a.month);
          return m != 0 ? m : a.teacherName.compareTo(b.teacherName);
        }),
    );
  }

  // ---------- subscriptions ----------

  Future<void> setStudentFee({
    required String centerId,
    required String actorId,
    required String studentId,
    required int monthlyFee,
  }) async {
    if (monthlyFee < 0) throw FinanceException('المبلغ غير صالح.');
    final student = await _ds.getDoc('students/$studentId');
    if (student == null || student['centerId'] != centerId) {
      throw FinanceException('لم يتم العثور على الطالب.');
    }
    final before = await _ds.getDoc('student_fees/$studentId');
    if (before != null && before['monthlyFee'] == monthlyFee) return;
    await _ds.commitBatch([
      BatchOp.set('student_fees/$studentId', {
        'centerId': centerId,
        'studentId': studentId,
        'monthlyFee': monthlyFee,
        'updatedAt': firestoreConverter.timestampOf(_now()),
      }),
      BatchOp.set(_auditPath(studentId),
          _audit(centerId, actorId, 'set_student_fee', 'student', studentId, {'monthlyFee': monthlyFee},
              before == null ? null : {'monthlyFee': before['monthlyFee']})),
    ]);
  }

  /// Issues the month's subscription to every ACTIVE student whose fee is set
  /// and who does not have one for that month yet. Safe to run again: existing
  /// subscriptions (and what was paid on them) are never touched. Returns how
  /// many were created.
  Future<int> issueSubscriptions({
    required String centerId,
    required String actorId,
    required String month,
  }) async {
    if (!isMonthKey(month)) throw FinanceException('الشهر غير صالح.');
    final fees = {
      for (final f in await _all('student_fees', centerId)) f['studentId'] as String: f['monthlyFee'] as int
    };
    final existing = {for (final s in await _all('subscriptions', centerId)) s['id'] as String};
    final students = await _ds.query('students', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('enrollmentStatus', 'active'),
    ]);
    final ops = <BatchOp>[];
    final now = firestoreConverter.timestampOf(_now());
    for (final s in students) {
      final id = s['id'] as String;
      final fee = fees[id] ?? 0;
      final subId = '${id}_$month';
      if (fee <= 0 || existing.contains(subId)) continue;
      ops.add(BatchOp.set('subscriptions/$subId', {
        'centerId': centerId,
        'studentId': id,
        'studentName': (s['preferredName'] as String?) ?? (s['fullName'] as String? ?? ''),
        'month': month,
        'amountDue': fee,
        'amountPaid': 0,
        'waived': false,
        'createdAt': now,
      }));
    }
    if (ops.isEmpty) return 0;
    // 450 per batch leaves room for the audit entry.
    for (var i = 0; i < ops.length; i += 450) {
      final chunk = ops.sublist(i, (i + 450).clamp(0, ops.length));
      await _ds.commitBatch([
        ...chunk,
        BatchOp.set('audit_logs/aud_${_now().microsecondsSinceEpoch}_subs_${month}_$i',
            _audit(centerId, actorId, 'issue_subscriptions', 'subscription', month, {'count': chunk.length})),
      ]);
    }
    return ops.length;
  }

  Future<void> recordPayment({
    required String centerId,
    required String actorId,
    required String paymentId,
    required String subscriptionId,
    required int amount,
    required PaymentMethod method,
    String? note,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) throw FinanceException('أدخل مبلغًا صحيحًا.');
    final when = paidAt ?? _now();
    if (when.isAfter(_now().add(const Duration(days: 1)))) {
      throw FinanceException('تاريخ الدفع لا يمكن أن يكون في المستقبل.');
    }
    final trimmed = note?.trim();
    await _ds.runTransaction((tx) async {
      if (await tx.get('payments/$paymentId') != null) return; // a retry: already recorded
      final sub = await tx.get('subscriptions/$subscriptionId');
      if (sub == null || sub['centerId'] != centerId) {
        throw FinanceException('لم يتم العثور على الاشتراك.');
      }
      if (sub['waived'] == true) throw FinanceException('هذا الاشتراك معفى.');
      final paid = sub['amountPaid'] as int;
      tx.set('payments/$paymentId', {
        'centerId': centerId,
        'subscriptionId': subscriptionId,
        'studentId': sub['studentId'],
        'amount': amount,
        'method': method.name,
        if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
        'paidAt': firestoreConverter.timestampOf(when),
        'receivedBy': actorId,
        'voided': false,
        'createdAt': firestoreConverter.timestampOf(_now()),
      });
      tx.update('subscriptions/$subscriptionId', {'amountPaid': paid + amount});
      tx.set(_auditPath(paymentId),
          _audit(centerId, actorId, 'record_payment', 'payment', paymentId,
              {'subscriptionId': subscriptionId, 'amount': amount}));
    });
  }

  Future<void> voidPayment({
    required String centerId,
    required String actorId,
    required String paymentId,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) throw FinanceException('سبب الإلغاء مطلوب.');
    await _ds.runTransaction((tx) async {
      final p = await tx.get('payments/$paymentId');
      if (p == null || p['centerId'] != centerId) throw FinanceException('لم يتم العثور على الدفعة.');
      if (p['voided'] == true) throw FinanceException('الدفعة ملغاة بالفعل.');
      final sub = await tx.get('subscriptions/${p['subscriptionId']}');
      tx.update('payments/$paymentId', {
        'voided': true,
        'voidReason': why,
        'voidedBy': actorId,
        'voidedAt': firestoreConverter.timestampOf(_now()),
      });
      if (sub != null) {
        tx.update('subscriptions/${p['subscriptionId']}',
            {'amountPaid': ((sub['amountPaid'] as int) - (p['amount'] as int)).clamp(0, 1 << 40)});
      }
      tx.set(_auditPath(paymentId),
          _audit(centerId, actorId, 'void_payment', 'payment', paymentId, {'voided': true, 'reason': why},
              {'amount': p['amount']}));
    });
  }

  Future<void> waiveSubscription({
    required String centerId,
    required String actorId,
    required String subscriptionId,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) throw FinanceException('سبب الإعفاء مطلوب.');
    final sub = await _ds.getDoc('subscriptions/$subscriptionId');
    if (sub == null || sub['centerId'] != centerId) throw FinanceException('لم يتم العثور على الاشتراك.');
    if (sub['waived'] == true) return;
    if ((sub['amountPaid'] as int) > 0) {
      throw FinanceException('عليه مدفوعات. ألغِها أولًا إن أردت الإعفاء.');
    }
    await _ds.commitBatch([
      BatchOp.update('subscriptions/$subscriptionId', {'waived': true, 'waivedReason': why}),
      BatchOp.set(_auditPath(subscriptionId),
          _audit(centerId, actorId, 'waive_subscription', 'subscription', subscriptionId, {'waived': true, 'reason': why})),
    ]);
  }

  // ---------- expenses ----------

  Future<void> addExpense({
    required String centerId,
    required String actorId,
    required String expenseId,
    required String category,
    required int amount,
    required DateTime date,
    String? description,
  }) async {
    if (amount <= 0) throw FinanceException('أدخل مبلغًا صحيحًا.');
    if (!expenseCategories.containsKey(category)) throw FinanceException('اختر بند المصروف.');
    if (date.isAfter(_now().add(const Duration(days: 1)))) {
      throw FinanceException('تاريخ المصروف لا يمكن أن يكون في المستقبل.');
    }
    final d = description?.trim();
    await _ds.runTransaction((tx) async {
      if (await tx.get('expenses/$expenseId') != null) return;
      tx.set('expenses/$expenseId', {
        'centerId': centerId,
        'category': category,
        'amount': amount,
        'date': firestoreConverter.timestampOf(date),
        if (d != null && d.isNotEmpty) 'description': d,
        'recordedBy': actorId,
        'voided': false,
        'createdAt': firestoreConverter.timestampOf(_now()),
      });
      tx.set(_auditPath(expenseId),
          _audit(centerId, actorId, 'add_expense', 'expense', expenseId, {'category': category, 'amount': amount}));
    });
  }

  Future<void> voidExpense({
    required String centerId,
    required String actorId,
    required String expenseId,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) throw FinanceException('سبب الإلغاء مطلوب.');
    final e = await _ds.getDoc('expenses/$expenseId');
    if (e == null || e['centerId'] != centerId) throw FinanceException('لم يتم العثور على المصروف.');
    if (e['voided'] == true) throw FinanceException('المصروف ملغى بالفعل.');
    await _ds.commitBatch([
      BatchOp.update('expenses/$expenseId', {
        'voided': true,
        'voidReason': why,
        'voidedBy': actorId,
        'voidedAt': firestoreConverter.timestampOf(_now()),
      }),
      BatchOp.set(_auditPath(expenseId),
          _audit(centerId, actorId, 'void_expense', 'expense', expenseId, {'voided': true, 'reason': why},
              {'amount': e['amount']})),
    ]);
  }

  // ---------- teacher wages ----------

  Future<void> setWageRate({
    required String centerId,
    required String actorId,
    required String teacherId,
    required int monthlyAmount,
  }) async {
    if (monthlyAmount < 0) throw FinanceException('المبلغ غير صالح.');
    final t = await _ds.getDoc('teachers/$teacherId');
    if (t == null || t['centerId'] != centerId) throw FinanceException('لم يتم العثور على المعلمة.');
    final before = await _ds.getDoc('wage_rates/$teacherId');
    if (before != null && before['monthlyAmount'] == monthlyAmount) return;
    await _ds.commitBatch([
      BatchOp.set('wage_rates/$teacherId', {
        'centerId': centerId,
        'teacherId': teacherId,
        'monthlyAmount': monthlyAmount,
        'updatedAt': firestoreConverter.timestampOf(_now()),
      }),
      BatchOp.set(_auditPath(teacherId),
          _audit(centerId, actorId, 'set_wage_rate', 'teacher', teacherId, {'monthlyAmount': monthlyAmount},
              before == null ? null : {'monthlyAmount': before['monthlyAmount']})),
    ]);
  }

  /// Creates the month's wage (at the agreed rate) for every ACTIVE teacher
  /// that has a rate and no wage for that month yet. Safe to repeat.
  Future<int> issueWages({
    required String centerId,
    required String actorId,
    required String month,
  }) async {
    if (!isMonthKey(month)) throw FinanceException('الشهر غير صالح.');
    final rates = {
      for (final r in await _all('wage_rates', centerId)) r['teacherId'] as String: r['monthlyAmount'] as int
    };
    final existing = {for (final w in await _all('wages', centerId)) w['id'] as String};
    final teachers = await _ds.query('teachers', where: [
      QueryFilter.equal('centerId', centerId),
      QueryFilter.equal('status', 'active'),
    ]);
    final ops = <BatchOp>[];
    final now = firestoreConverter.timestampOf(_now());
    for (final t in teachers) {
      final id = t['id'] as String;
      final rate = rates[id] ?? 0;
      final wageId = '${id}_$month';
      if (rate <= 0 || existing.contains(wageId)) continue;
      ops.add(BatchOp.set('wages/$wageId', {
        'centerId': centerId,
        'teacherId': id,
        'teacherName': t['fullName'] ?? '',
        'month': month,
        'baseAmount': rate,
        'adjustment': 0,
        'amount': rate,
        'status': 'due',
        'createdAt': now,
      }));
    }
    if (ops.isEmpty) return 0;
    await _ds.commitBatch([
      ...ops,
      BatchOp.set('audit_logs/aud_${_now().microsecondsSinceEpoch}_wages_$month',
          _audit(centerId, actorId, 'issue_wages', 'wage', month, {'count': ops.length})),
    ]);
    return ops.length;
  }

  /// A bonus (positive) or deduction (negative) on a wage that is still due.
  Future<void> adjustWage({
    required String centerId,
    required String actorId,
    required String wageId,
    required int adjustment,
    required String note,
  }) async {
    final why = note.trim();
    if (adjustment != 0 && why.isEmpty) throw FinanceException('اكتب سبب التعديل.');
    final w = await _ds.getDoc('wages/$wageId');
    if (w == null || w['centerId'] != centerId) throw FinanceException('لم يتم العثور على الأجر.');
    if (w['status'] == 'paid') throw FinanceException('الأجر مدفوع ولا يمكن تعديله.');
    final base = (w['baseAmount'] as int?) ?? (w['amount'] as int);
    final amount = base + adjustment;
    if (amount < 0) throw FinanceException('الخصم أكبر من الأجر.');
    await _ds.commitBatch([
      BatchOp.update('wages/$wageId', {
        'adjustment': adjustment,
        'adjustmentNote': why,
        'amount': amount,
      }),
      BatchOp.set(_auditPath(wageId),
          _audit(centerId, actorId, 'adjust_wage', 'wage', wageId, {'adjustment': adjustment, 'amount': amount},
              {'amount': w['amount']})),
    ]);
  }

  Future<void> payWage({
    required String centerId,
    required String actorId,
    required String wageId,
    required PaymentMethod method,
    DateTime? paidAt,
  }) async {
    final w = await _ds.getDoc('wages/$wageId');
    if (w == null || w['centerId'] != centerId) throw FinanceException('لم يتم العثور على الأجر.');
    if (w['status'] == 'paid') throw FinanceException('الأجر مدفوع بالفعل.');
    await _ds.commitBatch([
      BatchOp.update('wages/$wageId', {
        'status': 'paid',
        'paidBy': actorId,
        'paidAt': firestoreConverter.timestampOf(paidAt ?? _now()),
        'method': method.name,
      }),
      BatchOp.set(_auditPath(wageId),
          _audit(centerId, actorId, 'pay_wage', 'wage', wageId, {'amount': w['amount'], 'method': method.name})),
    ]);
  }
}
