/// Pricing plans and bundles configuration for Meshkah SaaS platform.
enum PlanTier {
  starter,
  growth,
  enterprise,
}

enum BillingCycle {
  monthly,
  yearly,
}

enum SupportedCurrency {
  egp,
  sar,
  usd,
}

class PricingBundle {
  const PricingBundle({
    required this.tier,
    required this.nameAr,
    required this.subtitleAr,
    required this.studentCapacity,
    required this.features,
    required this.monthlyPrices,
    required this.yearlyPrices,
    this.isPopular = false,
  });

  final PlanTier tier;
  final String nameAr;
  final String subtitleAr;
  final int? studentCapacity; // null = unlimited
  final List<String> features;
  final Map<SupportedCurrency, int> monthlyPrices;
  final Map<SupportedCurrency, int> yearlyPrices;
  final bool isPopular;

  int priceFor(BillingCycle cycle, SupportedCurrency currency) {
    if (cycle == BillingCycle.yearly) {
      return yearlyPrices[currency] ?? 0;
    }
    return monthlyPrices[currency] ?? 0;
  }

  String formatPrice(BillingCycle cycle, SupportedCurrency currency) {
    final amount = priceFor(cycle, currency);
    final symbol = switch (currency) {
      SupportedCurrency.egp => 'ج.م',
      SupportedCurrency.sar => 'ر.س',
      SupportedCurrency.usd => '\$',
    };
    final period = cycle == BillingCycle.yearly ? '/ سنوياً' : '/ شهرياً';
    return '$amount $symbol $period';
  }
}

class PricingPlans {
  static const starter = PricingBundle(
    tier: PlanTier.starter,
    nameAr: 'باقة الكتّاب',
    subtitleAr: 'مثالية للدور الناشئة والحلقات المبتدئة',
    studentCapacity: 50,
    monthlyPrices: {
      SupportedCurrency.egp: 299,
      SupportedCurrency.sar: 49,
      SupportedCurrency.usd: 15,
    },
    yearlyPrices: {
      SupportedCurrency.egp: 2990,
      SupportedCurrency.sar: 490,
      SupportedCurrency.usd: 150,
    },
    features: [
      'سعة حتى 50 طالباً وطالبة',
      'عدد حلقات ومعلمين غير محدود',
      'إدارة الحضور والغياب وجلسات التسميع',
      'تقييم الحفظ والتجويد برتب معتمدة',
      'العمل بدون اتصال بالإنترنت (Offline)',
      'حسابات مخصصة بلاحقة .meshkah',
    ],
  );

  static const growth = PricingBundle(
    tier: PlanTier.growth,
    nameAr: 'باقة المنارة',
    subtitleAr: 'الأنسب للدور المتنامية والمراكز المتوسطة',
    studentCapacity: 200,
    isPopular: true,
    monthlyPrices: {
      SupportedCurrency.egp: 699,
      SupportedCurrency.sar: 99,
      SupportedCurrency.usd: 29,
    },
    yearlyPrices: {
      SupportedCurrency.egp: 6990,
      SupportedCurrency.sar: 990,
      SupportedCurrency.usd: 290,
    },
    features: [
      'سعة حتى 200 طالب وطالبة',
      'كافة ميزات باقة الكتّاب',
      'نظام إدارة الاشتراكات والمصروفات والأجور',
      'تقارير تفصيلية مع التصدير لملفات CSV',
      'لوحة متابعة وإشراف تربوي متقدمة',
      'إعلانات المركز والتنبيهات الموجهة',
    ],
  );

  static const enterprise = PricingBundle(
    tier: PlanTier.enterprise,
    nameAr: 'باقة الصرح',
    subtitleAr: 'للمجمعات القرآنية الكبرى والفروع المتعددة',
    studentCapacity: null, // Unlimited
    monthlyPrices: {
      SupportedCurrency.egp: 1499,
      SupportedCurrency.sar: 199,
      SupportedCurrency.usd: 59,
    },
    yearlyPrices: {
      SupportedCurrency.egp: 14990,
      SupportedCurrency.sar: 1990,
      SupportedCurrency.usd: 590,
    },
    features: [
      'سعة طلاب ومعلمين غير محدودة',
      'دعم الفروع والمجمعات المتعددة',
      'كافة ميزات باقة المنارة المتقدمة',
      'نسخ احتياطي فوري وسجلات تدقيق كاملة',
      'أولوية الدعم الفني والمساعدة في الترحيل',
      'تخصيص كامل لمعايير التقييم والشهادات',
    ],
  );

  static const List<PricingBundle> all = [starter, growth, enterprise];
}
