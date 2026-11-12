/// Formatting helpers shared by the sales screens (history, detail, report,
/// dashboard figures). Amounts are TZS, shown without decimals.
class SalesFormat {
  SalesFormat._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// 842500 -> "TSh 842,500"
  static String money(num value) => 'TSh ${number(value)}';

  /// 842500 -> "842,500"
  static String number(num value) {
    final negative = value < 0;
    final s = value.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${negative ? '-' : ''}$buf';
  }

  /// 4620000 -> "TSh 4.62M", 24800 -> "TSh 24.8K"
  static String compactMoney(num value) {
    final v = value.abs();
    String body;
    if (v >= 1e9) {
      body = '${_trim(v / 1e9, 2)}B';
    } else if (v >= 1e6) {
      body = '${_trim(v / 1e6, 2)}M';
    } else if (v >= 1e4) {
      body = '${_trim(v / 1e3, 1)}K';
    } else {
      body = number(v);
    }
    return 'TSh ${value < 0 ? '-' : ''}$body';
  }

  /// 8.1 -> "▲ 8.1%", -3 -> "▼ 3.0%", null -> null
  static String? change(double? percent) {
    if (percent == null) return null;
    final arrow = percent >= 0 ? '▲' : '▼';
    return '$arrow ${percent.abs().toStringAsFixed(1)}%';
  }

  static String time(DateTime d) {
    final l = d.toLocal();
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  /// "10 Nov 2026"
  static String date(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  /// "10 Nov" (current year) or "10 Nov 2025"
  static String shortDate(DateTime d) {
    final l = d.toLocal();
    final now = DateTime.now();
    return l.year == now.year ? '${l.day} ${_months[l.month - 1]}' : date(l);
  }

  /// Today -> "Today", yesterday -> "Yesterday", else shortDate.
  static String dayLabel(DateTime d) {
    final l = d.toLocal();
    final today = DateTime.now();
    final day = DateTime(l.year, l.month, l.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return shortDate(l);
  }

  static String month(DateTime d) => _months[d.month - 1];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// Query-string date the CSP API expects: yyyy-MM-dd.
  static String apiDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String quantity(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _trim(double v, int digits) {
    var s = v.toStringAsFixed(digits);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
}
