/// Surah metadata only (name and number of ayat). No Quran text is stored or
/// generated here.
class Surah {
  const Surah(this.number, this.name, this.ayahCount);
  final int number;
  final String name;
  final int ayahCount;
}

const surahs = <Surah>[
  Surah(1, 'الفاتحة', 7),
  Surah(2, 'البقرة', 286),
  Surah(3, 'آل عمران', 200),
  Surah(4, 'النساء', 176),
  Surah(5, 'المائدة', 120),
  Surah(6, 'الأنعام', 165),
  Surah(7, 'الأعراف', 206),
  Surah(8, 'الأنفال', 75),
  Surah(9, 'التوبة', 129),
  Surah(10, 'يونس', 109),
  Surah(11, 'هود', 123),
  Surah(12, 'يوسف', 111),
  Surah(13, 'الرعد', 43),
  Surah(14, 'إبراهيم', 52),
  Surah(15, 'الحجر', 99),
  Surah(16, 'النحل', 128),
  Surah(17, 'الإسراء', 111),
  Surah(18, 'الكهف', 110),
  Surah(19, 'مريم', 98),
  Surah(20, 'طه', 135),
  Surah(21, 'الأنبياء', 112),
  Surah(22, 'الحج', 78),
  Surah(23, 'المؤمنون', 118),
  Surah(24, 'النور', 64),
  Surah(25, 'الفرقان', 77),
  Surah(26, 'الشعراء', 227),
  Surah(27, 'النمل', 93),
  Surah(28, 'القصص', 88),
  Surah(29, 'العنكبوت', 69),
  Surah(30, 'الروم', 60),
  Surah(31, 'لقمان', 34),
  Surah(32, 'السجدة', 30),
  Surah(33, 'الأحزاب', 73),
  Surah(34, 'سبأ', 54),
  Surah(35, 'فاطر', 45),
  Surah(36, 'يس', 83),
  Surah(37, 'الصافات', 182),
  Surah(38, 'ص', 88),
  Surah(39, 'الزمر', 75),
  Surah(40, 'غافر', 85),
  Surah(41, 'فصلت', 54),
  Surah(42, 'الشورى', 53),
  Surah(43, 'الزخرف', 89),
  Surah(44, 'الدخان', 59),
  Surah(45, 'الجاثية', 37),
  Surah(46, 'الأحقاف', 35),
  Surah(47, 'محمد', 38),
  Surah(48, 'الفتح', 29),
  Surah(49, 'الحجرات', 18),
  Surah(50, 'ق', 45),
  Surah(51, 'الذاريات', 60),
  Surah(52, 'الطور', 49),
  Surah(53, 'النجم', 62),
  Surah(54, 'القمر', 55),
  Surah(55, 'الرحمن', 78),
  Surah(56, 'الواقعة', 96),
  Surah(57, 'الحديد', 29),
  Surah(58, 'المجادلة', 22),
  Surah(59, 'الحشر', 24),
  Surah(60, 'الممتحنة', 13),
  Surah(61, 'الصف', 14),
  Surah(62, 'الجمعة', 11),
  Surah(63, 'المنافقون', 11),
  Surah(64, 'التغابن', 18),
  Surah(65, 'الطلاق', 12),
  Surah(66, 'التحريم', 12),
  Surah(67, 'الملك', 30),
  Surah(68, 'القلم', 52),
  Surah(69, 'الحاقة', 52),
  Surah(70, 'المعارج', 44),
  Surah(71, 'نوح', 28),
  Surah(72, 'الجن', 28),
  Surah(73, 'المزمل', 20),
  Surah(74, 'المدثر', 56),
  Surah(75, 'القيامة', 40),
  Surah(76, 'الإنسان', 31),
  Surah(77, 'المرسلات', 50),
  Surah(78, 'النبأ', 40),
  Surah(79, 'النازعات', 46),
  Surah(80, 'عبس', 42),
  Surah(81, 'التكوير', 29),
  Surah(82, 'الانفطار', 19),
  Surah(83, 'المطففين', 36),
  Surah(84, 'الانشقاق', 25),
  Surah(85, 'البروج', 22),
  Surah(86, 'الطارق', 17),
  Surah(87, 'الأعلى', 19),
  Surah(88, 'الغاشية', 26),
  Surah(89, 'الفجر', 30),
  Surah(90, 'البلد', 20),
  Surah(91, 'الشمس', 15),
  Surah(92, 'الليل', 21),
  Surah(93, 'الضحى', 11),
  Surah(94, 'الشرح', 8),
  Surah(95, 'التين', 8),
  Surah(96, 'العلق', 19),
  Surah(97, 'القدر', 5),
  Surah(98, 'البينة', 8),
  Surah(99, 'الزلزلة', 8),
  Surah(100, 'العاديات', 11),
  Surah(101, 'القارعة', 11),
  Surah(102, 'التكاثر', 8),
  Surah(103, 'العصر', 3),
  Surah(104, 'الهمزة', 9),
  Surah(105, 'الفيل', 5),
  Surah(106, 'قريش', 4),
  Surah(107, 'الماعون', 7),
  Surah(108, 'الكوثر', 3),
  Surah(109, 'الكافرون', 6),
  Surah(110, 'النصر', 3),
  Surah(111, 'المسد', 5),
  Surah(112, 'الإخلاص', 4),
  Surah(113, 'الفلق', 5),
  Surah(114, 'الناس', 6),
];

/// The surah with this number (1-114), or null.
Surah? surahByNumber(int number) =>
    (number >= 1 && number <= surahs.length) ? surahs[number - 1] : null;

/// Why an ayah range is invalid, or null when it is valid.
String? validateAyahRange(int surah, int startAyah, int endAyah) {
  final s = surahByNumber(surah);
  if (s == null) return 'اختر سورة صحيحة';
  if (startAyah < 1 || startAyah > s.ayahCount) {
    return 'آية البداية بين 1 و ${s.ayahCount}';
  }
  if (endAyah < 1 || endAyah > s.ayahCount) {
    return 'آية النهاية بين 1 و ${s.ayahCount}';
  }
  if (endAyah < startAyah) return 'آية النهاية يجب ألا تسبق آية البداية';
  return null;
}
