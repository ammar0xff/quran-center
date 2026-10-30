import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:quran_center/design_system/components/marks.dart';
import 'package:quran_center/design_system/components/empty_state.dart';
import 'package:quran_center/design_system/components/q_app_bar.dart';
import 'package:quran_center/core/auth/session_provider.dart';
import 'package:quran_center/core/finance/finance_rules.dart';
import 'package:quran_center/core/finance/money.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/data/models/enums.dart';
import 'package:quran_center/data/providers/repositories.dart';
import 'package:quran_center/data/services/finance_service.dart';
import 'package:quran_center/features/director/widgets/director_bottom_nav.dart';

class _Bundle {
  const _Bundle(this.data, this.students, this.teachers);
  final FinanceData data;
  final List<({String id, String name})> students;
  final List<({String id, String name})> teachers;
}

final _financeProvider = FutureProvider.autoDispose<_Bundle>((ref) async {
  final centerId = ref.watch(centerIdProvider);
  final (data, students, teachers) = await (
    ref.read(financeServiceProvider).load(centerId),
    ref.read(studentRepositoryProvider).getStudentsByCenter(centerId),
    ref.read(teacherRepositoryProvider).getTeachersByCenter(centerId),
  ).wait;
  return _Bundle(
    data,
    [
      for (final s in students)
        if (s.enrollmentStatus == EnrollmentStatus.active)
          (id: s.studentId, name: s.displayName)
    ]..sort((a, b) => a.name.compareTo(b.name)),
    [
      for (final t in teachers)
        if (t.status == AccountStatus.active)
          (id: t.teacherId, name: t.fullName)
    ]..sort((a, b) => a.name.compareTo(b.name)),
  );
});

Color _stateColor(SubscriptionState s) => switch (s) {
      SubscriptionState.paid ||
      SubscriptionState.overpaid =>
        DesignTokens.success,
      SubscriptionState.partial => DesignTokens.warning,
      SubscriptionState.unpaid => DesignTokens.error,
      SubscriptionState.waived => DesignTokens.secondaryText,
    };

/// The center's money: monthly subscriptions, expenses, teacher wages and a
/// summary. Director only; every figure is added up from recorded entries.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String _month = monthKey(DateTime.now());

  String get _centerId => ref.read(centerIdProvider);
  String get _actor => ref.read(actorProvider).id;
  FinanceService get _svc => ref.read(financeServiceProvider);

  void _shift(int by) {
    final s = monthStart(_month);
    setState(() => _month = monthKey(DateTime(s.year, s.month + by)));
  }

  Future<bool> _run(Future<void> Function() action, String? ok) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String m, bool good) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: good ? DesignTokens.success : DesignTokens.error));
    try {
      await action();
      ref.invalidate(_financeProvider);
      if (ok != null) say(ok, true);
      return true;
    } on FinanceException catch (e) {
      say(e.message, false);
    } catch (_) {
      say('تعذر تنفيذ العملية. لم يُسجَّل شيء، حاول مرة أخرى.', false);
    }
    return false;
  }

  Future<String?> _askText(String title, String label,
      {String? initial, bool number = false}) async {
    final c = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_financeProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: DesignTokens.warmOffWhite,
          appBar: QAppBar(
            title: const Text('المالية'),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      tooltip: 'الشهر السابق',
                      color: Colors.white,
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_right_rounded)),
                  Text(monthLabel(_month),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  IconButton(
                      tooltip: 'الشهر التالي',
                      color: Colors.white,
                      onPressed: () => _shift(1),
                      icon: const Icon(Icons.chevron_left_rounded)),
                ]),
                const TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Color(0xB3FFFFFF),
                    indicatorColor: DesignTokens.gold,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'الاشتراكات'),
                      Tab(text: 'المصروفات'),
                      Tab(text: 'الأجور'),
                      Tab(text: 'الملخص'),
                    ]),
              ]),
            ),
          ),
          body: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذر تحميل البيانات المالية'),
                const SizedBox(height: DesignTokens.space12),
                OutlinedButton(
                    onPressed: () => ref.invalidate(_financeProvider),
                    child: const Text('إعادة المحاولة')),
              ]),
            ),
            data: (b) => TabBarView(children: [
              _subscriptions(b),
              _expenses(b),
              _wages(b),
              _summary(b),
            ]),
          ),
          bottomNavigationBar: const DirectorBottomNav(currentIndex: 4),
        ),
      ),
    );
  }

  // ---------- subscriptions ----------

  Widget _subscriptions(_Bundle b) {
    final subs = b.data.subscriptions.where((s) => s.month == _month).toList();
    final withoutFee =
        b.students.where((s) => (b.data.fees[s.id] ?? 0) <= 0).length;
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final n = await _issueSubs();
                if (n != null && mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                        content: Text(n == 0
                            ? 'لا توجد اشتراكات جديدة لإصدارها.'
                            : 'أُصدر $n اشتراكًا.'),
                        backgroundColor: DesignTokens.success));
                }
              },
              icon: const Icon(Icons.playlist_add),
              label: const Text('إصدار اشتراكات الشهر'),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          OutlinedButton(
              onPressed: () => _editFees(b),
              child: const Text('الرسوم الشهرية')),
        ]),
        if (withoutFee > 0)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space8),
            child: Text(
                '$withoutFee طالبًا بلا رسوم محددة؛ لن يُصدر لهم اشتراك حتى تحدد رسومهم.',
                style:
                    const TextStyle(fontSize: 12, color: DesignTokens.warning)),
          ),
        const SizedBox(height: DesignTokens.space12),
        if (subs.isEmpty) EmptyState('لا توجد اشتراكات لهذا الشهر بعد.'),
        for (final s in subs)
          Card(
            child: ListTile(
              title: Text(s.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'المطلوب ${formatAmount(s.due)} • المدفوع ${formatAmount(s.paid)}'
                  '${s.owed > 0 ? ' • المتبقي ${formatAmount(s.owed)}' : ''}'),
              trailing: Text(subscriptionStateLabel(s.state),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _stateColor(s.state))),
              onTap: () => _openSubscription(b, s),
            ),
          ),
      ],
    );
  }

  Future<int?> _issueSubs() async {
    int? n;
    await _run(() async {
      n = await _svc.issueSubscriptions(
          centerId: _centerId, actorId: _actor, month: _month);
    }, null);
    return n;
  }

  Future<void> _editFees(_Bundle b) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(DesignTokens.space16),
              children: [
                const SectionTitle('الرسوم الشهرية لكل طالب'),
                for (final s in b.students)
                  ListTile(
                    title: Text(s.name),
                    trailing: Text((b.data.fees[s.id] ?? 0) > 0
                        ? formatAmount(b.data.fees[s.id]!)
                        : 'غير محددة'),
                    onTap: () async {
                      final t = await _askText(
                          'رسوم ${s.name}', 'المبلغ الشهري ($currencyLabel)',
                          number: true);
                      if (t == null) return;
                      final cents = parseAmount(t, allowZero: true);
                      if (cents == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'أدخل مبلغًا صحيحًا (رقم بحد أقصى خانتين عشريتين).'),
                              backgroundColor: DesignTokens.error));
                        }
                        return;
                      }
                      await _run(
                        () => _svc.setStudentFee(
                            centerId: _centerId,
                            actorId: _actor,
                            studentId: s.id,
                            monthlyFee: cents),
                        'حُفظت الرسوم',
                      );
                      final fresh = await ref.read(_financeProvider.future);
                      b.data.fees
                        ..clear()
                        ..addAll(fresh.data.fees);
                      setSheet(() {});
                    },
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openSubscription(_Bundle b, Subscription s) async {
    final payments =
        b.data.payments.where((p) => p.subscriptionId == s.id).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(DesignTokens.space16),
            children: [
              Text('${s.studentName} • ${monthLabel(s.month)}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                  'المطلوب ${formatAmount(s.due)} • المدفوع ${formatAmount(s.paid)} • ${subscriptionStateLabel(s.state)}'),
              const SizedBox(height: DesignTokens.space8),
              if (!s.waived)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _payDialog(s);
                  },
                  icon: const Icon(Icons.payments),
                  label: const Text('تسجيل دفعة'),
                ),
              if (!s.waived && s.paid == 0)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final why =
                        await _askText('إعفاء من الاشتراك', 'سبب الإعفاء *');
                    if (why == null) return;
                    await _run(
                      () => _svc.waiveSubscription(
                          centerId: _centerId,
                          actorId: _actor,
                          subscriptionId: s.id,
                          reason: why),
                      'تم الإعفاء',
                    );
                  },
                  child: const Text('إعفاء'),
                ),
              const Divider(),
              if (payments.isEmpty) const Text('لا توجد دفعات.'),
              for (final p in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatAmount(p.amount),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration:
                              p.voided ? TextDecoration.lineThrough : null)),
                  subtitle: Text(
                      '${DateFormat.yMMMd('ar').format(p.paidAt)} • ${paymentMethodLabel(p.method)}'
                      '${p.note == null ? '' : ' • ${p.note}'}${p.voided ? ' • ملغاة' : ''}'),
                  trailing: p.voided
                      ? null
                      : TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final why =
                                await _askText('إلغاء الدفعة', 'سبب الإلغاء *');
                            if (why == null) return;
                            await _run(
                              () => _svc.voidPayment(
                                  centerId: _centerId,
                                  actorId: _actor,
                                  paymentId: p.id,
                                  reason: why),
                              'أُلغيت الدفعة',
                            );
                          },
                          child: const Text('إلغاء'),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payDialog(Subscription s) async {
    final amount = TextEditingController(
        text: s.owed > 0
            ? (s.owed / 100).toString().replaceAll(RegExp(r'\.0$'), '')
            : '');
    final note = TextEditingController();
    var method = PaymentMethod.cash;
    final id = 'pay_${DateTime.now().microsecondsSinceEpoch}';
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('دفعة من ${s.studentName}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'المبلغ ($currencyLabel) *', errorText: error),
              ),
              const SizedBox(height: DesignTokens.space8),
              DropdownButtonFormField<PaymentMethod>(
                value: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem(
                        value: m, child: Text(paymentMethodLabel(m))),
                ],
                onChanged: (v) => setD(() => method = v ?? method),
              ),
              TextField(
                  controller: note,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظة (اختياري)')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  if (parseAmount(amount.text) == null) {
                    setD(() => error = 'أدخل مبلغًا صحيحًا');
                  } else {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('تسجيل'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => _svc.recordPayment(
          centerId: _centerId,
          actorId: _actor,
          paymentId: id,
          subscriptionId: s.id,
          amount: parseAmount(amount.text)!,
          method: method,
          note: note.text),
      'سُجّلت الدفعة',
    );
  }

  // ---------- expenses ----------

  Widget _expenses(_Bundle b) {
    final from = monthStart(_month), to = nextMonthStart(_month);
    final items = b.data.expenses
        .where((e) => !e.date.isBefore(from) && e.date.isBefore(to))
        .toList();
    final total =
        items.where((e) => !e.voided).fold<int>(0, (a, e) => a + e.amount);
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        FilledButton.icon(
          onPressed: _addExpense,
          icon: const Icon(Icons.add),
          label: const Text('تسجيل مصروف'),
        ),
        const SizedBox(height: DesignTokens.space8),
        Text('إجمالي المصروفات: ${formatAmount(total)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: DesignTokens.space8),
        if (items.isEmpty) EmptyState('لا توجد مصروفات في هذا الشهر.'),
        for (final e in items)
          Card(
            child: ListTile(
              title: Text(
                  '${expenseCategories[e.category] ?? e.category} • ${formatAmount(e.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration:
                          e.voided ? TextDecoration.lineThrough : null)),
              subtitle: Text([
                DateFormat.yMMMd('ar').format(e.date),
                if (e.description.isNotEmpty) e.description,
                if (e.voided) 'ملغى: ${e.voidReason ?? ''}',
              ].join(' • ')),
              trailing: e.voided
                  ? null
                  : TextButton(
                      onPressed: () async {
                        final why =
                            await _askText('إلغاء المصروف', 'سبب الإلغاء *');
                        if (why == null) return;
                        await _run(
                          () => _svc.voidExpense(
                              centerId: _centerId,
                              actorId: _actor,
                              expenseId: e.id,
                              reason: why),
                          'أُلغي المصروف',
                        );
                      },
                      child: const Text('إلغاء'),
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _addExpense() async {
    final amount = TextEditingController();
    final desc = TextEditingController();
    var category = 'rent';
    var date = DateTime.now();
    String? error;
    final id = 'exp_${DateTime.now().microsecondsSinceEpoch}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('تسجيل مصروف'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'البند'),
                  items: [
                    for (final e in expenseCategories.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setD(() => category = v ?? category),
                ),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'المبلغ ($currencyLabel) *', errorText: error),
                ),
                TextField(
                    controller: desc,
                    decoration:
                        const InputDecoration(labelText: 'البيان (اختياري)')),
                const SizedBox(height: DesignTokens.space8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) setD(() => date = d);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat.yMMMd('ar').format(date)),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  if (parseAmount(amount.text) == null) {
                    setD(() => error = 'أدخل مبلغًا صحيحًا');
                  } else {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('تسجيل'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => _svc.addExpense(
          centerId: _centerId,
          actorId: _actor,
          expenseId: id,
          category: category,
          amount: parseAmount(amount.text)!,
          date: date,
          description: desc.text),
      'سُجّل المصروف',
    );
  }

  // ---------- wages ----------

  Widget _wages(_Bundle b) {
    final items = b.data.wages.where((w) => w.month == _month).toList();
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _run(() async {
                await _svc.issueWages(
                    centerId: _centerId, actorId: _actor, month: _month);
              }, 'أُصدرت أجور الشهر'),
              icon: const Icon(Icons.playlist_add),
              label: const Text('إصدار أجور الشهر'),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          OutlinedButton(
              onPressed: () => _editRates(b),
              child: const Text('الأجر المتفق عليه')),
        ]),
        const SizedBox(height: DesignTokens.space12),
        if (items.isEmpty) EmptyState('لا توجد أجور لهذا الشهر بعد.'),
        for (final w in items)
          Card(
            child: ListTile(
              title: Text(w.teacherName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                'الأجر ${formatAmount(w.amount)}',
                if (w.adjustment != 0)
                  '(${w.adjustment > 0 ? '+' : ''}${formatAmount(w.adjustment)}: ${w.adjustmentNote ?? ''})',
                if (w.paid && w.paidAt != null)
                  'دُفع ${DateFormat.yMMMd('ar').format(w.paidAt!)} • ${paymentMethodLabel(w.method)}',
              ].join(' ')),
              trailing: w.paid
                  ? const Text('مدفوع',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.success))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                          onPressed: () => _adjustWage(w),
                          child: const Text('تعديل')),
                      FilledButton(
                          onPressed: () => _payWage(w),
                          child: const Text('دفع')),
                    ]),
            ),
          ),
      ],
    );
  }

  Future<void> _editRates(_Bundle b) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(DesignTokens.space16),
              children: [
                const SectionTitle('الأجر الشهري المتفق عليه'),
                if (b.teachers.isEmpty) const Text('لا يوجد معلمون نشطون.'),
                for (final t in b.teachers)
                  ListTile(
                    title: Text(t.name),
                    trailing: Text((b.data.rates[t.id] ?? 0) > 0
                        ? formatAmount(b.data.rates[t.id]!)
                        : 'غير محدد'),
                    onTap: () async {
                      final v = await _askText(
                          'أجر ${t.name}', 'المبلغ الشهري ($currencyLabel)',
                          number: true);
                      if (v == null) return;
                      final cents = parseAmount(v, allowZero: true);
                      if (cents == null) return;
                      await _run(
                        () => _svc.setWageRate(
                            centerId: _centerId,
                            actorId: _actor,
                            teacherId: t.id,
                            monthlyAmount: cents),
                        'حُفظ الأجر',
                      );
                      final fresh = await ref.read(_financeProvider.future);
                      b.data.rates
                        ..clear()
                        ..addAll(fresh.data.rates);
                      setSheet(() {});
                    },
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _adjustWage(Wage w) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var bonus = true;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('تعديل أجر ${w.teacherName}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('مكافأة')),
                  ButtonSegment(value: false, label: Text('خصم')),
                ],
                selected: {bonus},
                onSelectionChanged: (v) => setD(() => bonus = v.first),
              ),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'المبلغ ($currencyLabel) *', errorText: error),
              ),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'السبب *')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  if (parseAmount(amount.text, allowZero: true) == null) {
                    setD(() => error = 'أدخل مبلغًا صحيحًا');
                  } else {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final cents = parseAmount(amount.text, allowZero: true)!;
    await _run(
      () => _svc.adjustWage(
          centerId: _centerId,
          actorId: _actor,
          wageId: w.id,
          adjustment: bonus ? cents : -cents,
          note: note.text),
      'عُدّل الأجر',
    );
  }

  Future<void> _payWage(Wage w) async {
    var method = PaymentMethod.cash;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('دفع ${formatAmount(w.amount)} إلى ${w.teacherName}'),
            content: DropdownButtonFormField<PaymentMethod>(
              value: method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: [
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(
                      value: m, child: Text(paymentMethodLabel(m))),
              ],
              onChanged: (v) => setD(() => method = v ?? method),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('تأكيد الدفع')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => _svc.payWage(
          centerId: _centerId, actorId: _actor, wageId: w.id, method: method),
      'سُجّل دفع الأجر',
    );
  }

  // ---------- summary ----------

  Widget _summary(_Bundle b) {
    final s = b.data.summary(_month);
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(
              vertical: DesignTokens.space8, horizontal: DesignTokens.space16),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style:
                        TextStyle(fontWeight: bold ? FontWeight.w800 : null))),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: [
        Card(
          child: Column(children: [
            row('المحصَّل في الشهر', formatAmount(s.collected)),
            const Divider(height: 1),
            row('المصروفات', formatAmount(s.expenses)),
            const Divider(height: 1),
            row('أجور مدفوعة', formatAmount(s.wagesPaid)),
            const Divider(height: 1),
            row('الصافي النقدي', formatAmount(s.net), bold: true),
          ]),
        ),
        const SizedBox(height: DesignTokens.space12),
        Card(
          child: Column(children: [
            row('اشتراكات الشهر المصدَرة', formatAmount(s.charged)),
            const Divider(height: 1),
            row('المتبقي على اشتراكات الشهر', formatAmount(s.outstandingTotal)),
            const Divider(height: 1),
            row('أجور الشهر غير المدفوعة', formatAmount(s.wagesDue)),
          ]),
        ),
        if (s.expensesByCategory.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.space12),
          Card(
            child: Column(children: [
              for (final e in s.expensesByCategory.entries)
                row(expenseCategories[e.key] ?? e.key, formatAmount(e.value)),
            ]),
          ),
        ],
        const SizedBox(height: DesignTokens.space12),
        const Text(
          'الصافي النقدي = ما قُبض في الشهر − المصروفات − الأجور المدفوعة فيه. لا يدخل فيه ما هو مستحق '
          'ولم يُقبض بعد، ولا الأجور غير المدفوعة، ولا الدفعات الملغاة.',
          style: TextStyle(
              fontSize: 12, color: DesignTokens.secondaryText, height: 1.5),
        ),
      ],
    );
  }
}
