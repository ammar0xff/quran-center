import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_center/core/auth/app_session.dart';
import 'package:quran_center/core/theme/design_tokens.dart';
import 'package:quran_center/design_system/components/rosette.dart';

/// Screen displayed when a center's subscription has ended.
/// Transforms the app into an interactive Electronic Tasbeeh & Azkar sanctuary,
/// while providing full reassurance that all center records are completely safe
/// and offering a 1-tap route to renew the subscription.
class TasbeehAndAzkarScreen extends StatefulWidget {
  const TasbeehAndAzkarScreen({super.key});

  @override
  State<TasbeehAndAzkarScreen> createState() => _TasbeehAndAzkarScreenState();
}

class _TasbeehAndAzkarScreenState extends State<TasbeehAndAzkarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _counter = 0;
  int _totalCount = 0;

  final List<String> _adhkarOptions = [
    'سبحان الله وبحمده، سبحان الله العظيم',
    'أستغفر الله العظيم وأتوب إليه',
    'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
    'اللهم صلِّ وسلّم وبارك على نبينا محمد',
    'لا حول ولا قوة إلا بالله العلي العظيم',
    'سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر',
  ];
  late String _selectedDhikr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDhikr = _adhkarOptions.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() {
      _counter++;
      _totalCount++;
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignTokens.warmOffWhite,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Reassurance and Renewal Banner
              _ReassuranceBanner(
                onRenew: () => context.push(Routes.pricing),
              ),

              // 2. Tab Bar (المسبحة الإلكترونية | أذكار الصباح والمساء | أذكار بعد الصلاة)
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: DesignTokens.gold,
                  labelColor: DesignTokens.primaryDarkGreen,
                  unselectedLabelColor: DesignTokens.secondaryText,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.fingerprint_rounded), text: 'المسبحة الذكية'),
                    Tab(icon: Icon(Icons.wb_sunny_rounded), text: 'أذكار الصباح والمساء'),
                    Tab(icon: Icon(Icons.menu_book_rounded), text: 'أدعية وأذكار'),
                  ],
                ),
              ),

              // 3. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Electronic Tasbeeh
                    _TasbeehView(
                      counter: _counter,
                      totalCount: _totalCount,
                      selectedDhikr: _selectedDhikr,
                      adhkarOptions: _adhkarOptions,
                      onDhikrChanged: (d) => setState(() {
                        _selectedDhikr = d;
                        _counter = 0;
                      }),
                      onIncrement: _increment,
                      onReset: _reset,
                    ),

                    // Tab 2: Morning & Evening Azkar
                    _MorningEveningAzkarView(),

                    // Tab 3: Post-Prayer Supplications
                    _PostPrayerAzkarView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top reassuring notification requested by the user.
class _ReassuranceBanner extends StatelessWidget {
  const _ReassuranceBanner({required this.onRenew});

  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E5A47), // Emerald
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRenew,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Rosette(
                  size: 44,
                  color: DesignTokens.gold,
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'انتهت فترة اشتراك داركم',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE9CF93),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.shield_rounded, size: 14, color: Color(0xFFE9CF93)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'بياناتكم وطلابكم وحلقاتكم وسجلاتكم محفوظة تماماً بأمان 🔒',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'اضغط هنا لتجديد الاشتراك ومتابعة إدارة الحلقات',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: DesignTokens.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'تجديد',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A3A30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The interactive Tasbeeh View
class _TasbeehView extends StatelessWidget {
  const _TasbeehView({
    required this.counter,
    required this.totalCount,
    required this.selectedDhikr,
    required this.adhkarOptions,
    required this.onDhikrChanged,
    required this.onIncrement,
    required this.onReset,
  });

  final int counter;
  final int totalCount;
  final String selectedDhikr;
  final List<String> adhkarOptions;
  final ValueChanged<String> onDhikrChanged;
  final VoidCallback onIncrement;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Dhikr selector dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DesignTokens.borders),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDhikr,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: DesignTokens.primaryDarkGreen),
                items: adhkarOptions.map((d) {
                  return DropdownMenuItem<String>(
                    value: d,
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.mainText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onDhikrChanged(val);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Big Dhikr Text display in Amiri font
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DesignTokens.borders),
            ),
            child: Text(
              selectedDhikr,
              style: const TextStyle(
                fontFamily: DesignTokens.nameFont,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E5A47),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // Giant Circular Tasbeeh Button
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF168A57), Color(0xFF0E5A47), Color(0xFF0A3A30)],
                  stops: [0.0, 0.7, 1.0],
                ),
                border: Border.all(color: DesignTokens.gold, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E5A47).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$counter',
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'المس للتسبيح',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE9CF93),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Total & Reset bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DesignTokens.borders),
                ),
                child: Text(
                  'مجموع التسبيحات: $totalCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('تصفير'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Morning and evening Azkar cards
class _MorningEveningAzkarView extends StatelessWidget {
  final List<Map<String, String>> _morningAzkar = const [
    {
      'title': 'سيد الاستغفار',
      'body':
          'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ.',
      'count': 'مرة واحدة',
    },
    {
      'title': 'آية الكرسي',
      'body':
          'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ...',
      'count': 'مرة واحدة',
    },
    {
      'title': 'المعوذات (الإخلاص، الفلق، الناس)',
      'body': 'قُلْ هُوَ اللَّهُ أَحَدٌ ... قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ... قُلْ أَعُوذُ بِرَبِّ النَّاسِ ...',
      'count': '3 مرات',
    },
    {
      'title': 'الحماية والتحصين',
      'body': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
      'count': '3 مرات',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _morningAzkar.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = _morningAzkar[i];
        return _ZikrCard(
          title: a['title']!,
          body: a['body']!,
          count: a['count']!,
        );
      },
    );
  }
}

/// Post-prayer Azkar cards
class _PostPrayerAzkarView extends StatelessWidget {
  final List<Map<String, String>> _prayerAzkar = const [
    {
      'title': 'الاستغفار بعد الصلاة',
      'body': 'أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ، اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
      'count': 'مرة واحدة',
    },
    {
      'title': 'التسبيح والتحميد والتكبير',
      'body': 'سُبْحَانَ اللهِ (33 مرة) ، وَالْحَمْدُ للهِ (33 مرة) ، وَاللهُ أَكْبَرُ (33 مرة) ، تمام المائة: لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': '33 مرة كل ذكر',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _prayerAzkar.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = _prayerAzkar[i];
        return _ZikrCard(
          title: a['title']!,
          body: a['body']!,
          count: a['count']!,
        );
      },
    );
  }
}

class _ZikrCard extends StatelessWidget {
  const _ZikrCard({
    required this.title,
    required this.body,
    required this.count,
  });

  final String title;
  final String body;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.mainText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DesignTokens.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesignTokens.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  count,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B4E1B),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            body,
            style: const TextStyle(
              fontFamily: DesignTokens.nameFont,
              fontSize: 17,
              height: 1.6,
              color: Color(0xFF0E5A47),
            ),
          ),
        ],
      ),
    );
  }
}
