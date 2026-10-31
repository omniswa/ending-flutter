const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String formatShortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}';

String formatTimestamp(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year} - $hour:$minute$period';
}

DateTime? parseLongDate(String input) {
  final m = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$')
      .firstMatch(input.trim());
  if (m == null) return null;
  final month = _months.indexWhere(
    (x) => x.toLowerCase() == m.group(1)!.toLowerCase(),
  );
  if (month < 0) return null;
  return DateTime(int.parse(m.group(3)!), month + 1, int.parse(m.group(2)!));
}

String formatPercent(double p) => '${(p * 100).floor()}%';

String formatTimeLeft(int minutes) {
  if (minutes <= 0) return 'Done';
  if (minutes < 60) return '$minutes min left';
  return '${minutes ~/ 60}h ${minutes % 60}m left';
}
