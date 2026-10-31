import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/config/pricing_plans.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/app_hero.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// Screen displaying the SaaS subscription plans and Paymob checkout triggers.
class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  BillingCycle _selectedCycle = BillingCycle.yearly;
  SupportedCurrency _selectedCurrency = SupportedCurrency.egp;

  void _onSubscribe(PricingBundle bundle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PaymobCheckoutSheet(
        bundle: bundle,
        cycle: _selectedCycle,
        currency: _selectedCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0E5A47),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'باقات اشتراك مشكاة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              AppHero(
                bottomRadius: 36,
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Rosette(
                        size: 54,
                        color: DesignTokens.gold,
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'اختر الباقة المناسبة لحجم داركم',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اشتراك شفاف، تفعيل فوري، ودفع آمن عبر Paymob',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // Toggle Controls (Cycle & Currency)
                      _PricingControls(
                        selectedCycle: _selectedCycle,
                        onCycleChanged: (c) => setState(() => _selectedCycle = c),
                        selectedCurrency: _selectedCurrency,
                        onCurrencyChanged: (cur) =>
                            setState(() => _selectedCurrency = cur),
                      ),

                      const SizedBox(height: 24),

                      // Bundle Cards
                      for (final bundle in PricingPlans.all) ...[
                        _BundleCard(
                          bundle: bundle,
                          cycle: _selectedCycle,
                          currency: _selectedCurrency,
                          onSelect: () => _onSubscribe(bundle),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 24),

                      // Paymob Security Badge
                      _PaymobTrustFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingControls extends StatelessWidget {
  const _PricingControls({
    required this.selectedCycle,
    required this.onCycleChanged,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  final BillingCycle selectedCycle;
  final ValueChanged<BillingCycle> onCycleChanged;
  final SupportedCurrency selectedCurrency;
  final ValueChanged<SupportedCurrency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        children: [
          // Billing cycle selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: DesignTokens.warmOffWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CycleOption(
                    title: 'اشتراك سنوي (وفر شهرين 🎁)',
                    isSelected: selectedCycle == BillingCycle.yearly,
                    onTap: () => onCycleChanged(BillingCycle.yearly),
                  ),
                ),
                Expanded(
                  child: _CycleOption(
                    title: 'اشتراك شهري',
                    isSelected: selectedCycle == BillingCycle.monthly,
                    onTap: () => onCycleChanged(BillingCycle.monthly),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Currency selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'العملة: ',
                style: TextStyle(fontSize: 13, color: DesignTokens.secondaryText),
              ),
              const SizedBox(width: 8),
              _CurrencyChip(
                label: 'ج.م (مصر)',
                isSelected: selectedCurrency == SupportedCurrency.egp,
                onTap: () => onCurrencyChanged(SupportedCurrency.egp),
              ),
              const SizedBox(width: 6),
              _CurrencyChip(
                label: 'ر.س (السعودية)',
                isSelected: selectedCurrency == SupportedCurrency.sar,
                onTap: () => onCurrencyChanged(SupportedCurrency.sar),
              ),
              const SizedBox(width: 6),
              _CurrencyChip(
                label: '\$ (دولار)',
                isSelected: selectedCurrency == SupportedCurrency.usd,
                onTap: () => onCurrencyChanged(SupportedCurrency.usd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CycleOption extends StatelessWidget {
  const _CycleOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0E5A47) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : DesignTokens.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.gold.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? DesignTokens.gold : DesignTokens.borders,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF6B4E1B) : DesignTokens.mainText,
          ),
        ),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.cycle,
    required this.currency,
    required this.onSelect,
  });

  final PricingBundle bundle;
  final BillingCycle cycle;
  final SupportedCurrency currency;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final priceStr = bundle.formatPrice(cycle, currency);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(
          color: bundle.isPopular ? DesignTokens.gold : DesignTokens.borders,
          width: bundle.isPopular ? 2 : 1,
        ),
        boxShadow: bundle.isPopular
            ? [
                BoxShadow(
                  color: DesignTokens.gold.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bundle.isPopular)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: DesignTokens.gold,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'الباقة الأكثر طلباً واختياراً ⭐',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A3A30),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      bundle.nameAr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.mainText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F1EA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bundle.studentCapacity == null
                            ? 'طلاب غير محدود'
                            : 'حتى ${bundle.studentCapacity} طالب',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0E5A47),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bundle.subtitleAr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: DesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  priceStr,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E5A47),
                  ),
                ),
                const Divider(height: 28),
                for (final feat in bundle.features) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: DesignTokens.primaryDarkGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feat,
                          style: const TextStyle(
                            fontSize: 13,
                            color: DesignTokens.mainText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: bundle.isPopular
                        ? DesignTokens.gold
                        : const Color(0xFF0E5A47),
                    foregroundColor: bundle.isPopular
                        ? const Color(0xFF0A3A30)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onSelect,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text(
                    'اشترك الآن عبر Paymob',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymobTrustFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: DesignTokens.primaryDarkGreen),
              const SizedBox(width: 6),
              const Text(
                'بوابة دفع آمنة 100% ومعتمدة عبر Paymob',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'نقبل بطاقات فيزا، ماستركارد، بطاقة ميزة، ومحافظ الهواتف الذكية (فودافون كاش، أورنج، اتصالات، إنستاباي).',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PaymobCheckoutSheet extends StatelessWidget {
  const _PaymobCheckoutSheet({
    required this.bundle,
    required this.cycle,
    required this.currency,
  });

  final PricingBundle bundle;
  final BillingCycle cycle;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final priceStr = bundle.formatPrice(cycle, currency);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تأكيد الاشتراك عبر Paymob',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'الباقة المختارة: ${bundle.nameAr}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'المبلغ الإجمالي: $priceStr',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DesignTokens.emerald,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, color: DesignTokens.primaryDarkGreen, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'سيتم نقلك إلى صفحة الدفع الموحدة الآمنة لإتمام المعاملة.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'جاري تهيئة جلسة الدفع الآمنة عبر Paymob...',
                      style: TextStyle(fontFamily: DesignTokens.nameFont),
                    ),
                    backgroundColor: Color(0xFF0E5A47),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('المتابعة إلى بوابة Paymob الآمنة'),
            ),
          ],
        ),
      ),
    );
  }
}
