const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Parses dates like "October 1, 2026". Returns null when malformed.
DateTime? parseLongDate(String input) {
  final m = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$').firstMatch(input.trim());
  if (m == null) return null;
  final month = _months.indexWhere((x) => x.toLowerCase() == m.group(1)!.toLowerCase());
  if (month < 0) return null;
  return DateTime(int.parse(m.group(3)!), month + 1, int.parse(m.group(2)!));
}

String formatPercent(double p) => '${(p * 100).round()}%';

String formatTimeLeft(int minutes) {
  if (minutes <= 0) return 'Done';
  if (minutes < 60) return '$minutes min left';
  return '${minutes ~/ 60}h ${minutes % 60}m left';
}
