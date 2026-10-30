/// Money is stored as a whole number of the smallest unit (قرش = 1/100), never
/// as a floating-point number, so sums are exact.
const currencyLabel = 'ج.م';

/// Parses what a person types ("150", "150.5", "١٥٠٫٥٠", "1,250") into
/// minor units, or null if it is not a valid positive amount with at most two
/// decimals.
int? parseAmount(String input, {bool allowZero = false}) {
  var t = input.trim();
  if (t.isEmpty) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  t = t
      .split('')
      .map((c) {
        final i = arabic.indexOf(c);
        return i >= 0 ? '$i' : c;
      })
      .join()
      .replaceAll('٫', '.')
      .replaceAll('٬', '')
      .replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  final parts = t.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 100000000) return null;
  final frac = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final cents = whole * 100 + frac;
  if (cents == 0 && !allowZero) return null;
  return cents;
}

/// 125050 -> "1,250.50 ج.م"; whole amounts drop the decimals: "1,250 ج.م".
String formatAmount(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final frac = abs % 100;
  final grouped =
      whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final body =
      frac == 0 ? grouped : '$grouped.${frac.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$body $currencyLabel';
}

/// "2026-11" for a date.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

bool isMonthKey(String s) => RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(s);

DateTime monthStart(String key) =>
    DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(5, 7)));

DateTime nextMonthStart(String key) {
  final s = monthStart(key);
  return DateTime(s.year, s.month + 1);
}

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String monthLabel(String key) {
  final s = monthStart(key);
  return '${_months[s.month - 1]} ${s.year}';
}
