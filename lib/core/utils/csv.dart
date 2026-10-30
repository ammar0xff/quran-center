/// Encodes rows as CSV (RFC 4180 quoting).
///
/// Cells that a spreadsheet would run as a formula (starting with `=`, `+`,
/// `-` or `@`) are prefixed with an apostrophe so exported text can never
/// execute when the file is opened.
String toCsv(List<String> headers, List<List<Object?>> rows) {
  String cell(Object? v) {
    var s = v == null ? '' : '$v';
    if (s.isNotEmpty && '=+-@'.contains(s[0]) && double.tryParse(s) == null) s = "'$s";
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  return [headers, ...rows].map((r) => r.map(cell).join(',')).join('\r\n');
}
