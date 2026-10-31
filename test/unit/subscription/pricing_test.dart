import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/config/pricing_plans.dart';

void main() {
  group('PricingPlans Config Tests', () {
    test('contains all three standard tiers', () {
      expect(PricingPlans.all.length, 3);
      expect(PricingPlans.starter.tier, PlanTier.starter);
      expect(PricingPlans.growth.tier, PlanTier.growth);
      expect(PricingPlans.enterprise.tier, PlanTier.enterprise);
    });

    test('student capacity is configured correctly per tier', () {
      expect(PricingPlans.starter.studentCapacity, 50);
      expect(PricingPlans.growth.studentCapacity, 200);
      expect(PricingPlans.enterprise.studentCapacity, isNull); // Unlimited
    });

    test('yearly price gives exactly 2 months free discount compared to monthly', () {
      for (final bundle in PricingPlans.all) {
        for (final currency in SupportedCurrency.values) {
          final monthly = bundle.priceFor(BillingCycle.monthly, currency);
          final yearly = bundle.priceFor(BillingCycle.yearly, currency);
          // 12 months for the price of 10 months: yearly == monthly * 10
          expect(yearly, monthly * 10,
              reason: '${bundle.nameAr} in $currency should be 10x monthly price');
        }
      }
    });

    test('formatPrice produces localized price with currency symbol', () {
      final starterMonthlyEgp =
          PricingPlans.starter.formatPrice(BillingCycle.monthly, SupportedCurrency.egp);
      expect(starterMonthlyEgp, contains('299'));
      expect(starterMonthlyEgp, contains('ج.م'));
      expect(starterMonthlyEgp, contains('شهرياً'));

      final growthYearlySar =
          PricingPlans.growth.formatPrice(BillingCycle.yearly, SupportedCurrency.sar);
      expect(growthYearlySar, contains('990'));
      expect(growthYearlySar, contains('ر.س'));
      expect(growthYearlySar, contains('سنوياً'));

      final enterpriseMonthlyUsd =
          PricingPlans.enterprise.formatPrice(BillingCycle.monthly, SupportedCurrency.usd);
      expect(enterpriseMonthlyUsd, contains('59'));
      expect(enterpriseMonthlyUsd, contains('\$'));
    });
  });
}
