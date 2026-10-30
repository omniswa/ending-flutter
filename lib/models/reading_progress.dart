import 'package:flutter/foundation.dart';

@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.chapter,
    required this.scroll,
    required this.percent,
    required this.minutesLeft,
    required this.lastOpened,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> j) => ReadingProgress(
    bookId: j['bookId'] as int,
    chapter: j['chapter'] as int,
    scroll: (j['scroll'] as num).toDouble(),
    percent: (j['percent'] as num).toDouble(),
    minutesLeft: j['minutesLeft'] as int,
    lastOpened: DateTime.parse(j['lastOpened'] as String),
  );

  final int bookId;
  final int chapter;

  final double scroll;

  final double percent;
  final int minutesLeft;
  final DateTime lastOpened;

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapter': chapter,
    'scroll': scroll,
    'percent': percent,
    'minutesLeft': minutesLeft,
    'lastOpened': lastOpened.toIso8601String(),
  };
}
