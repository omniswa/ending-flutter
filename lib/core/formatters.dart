const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Oct 27" — compact form for tight spaces.
String formatShortDate(DateTime d) => '${_months[d.month - 1].substring(0, 3)} ${d.day}';

/// Parses "October 1, 2026" or ISO "2026-10-01". Returns null when malformed.
DateTime? parseLongDate(String input) {
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(input.trim());
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
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
