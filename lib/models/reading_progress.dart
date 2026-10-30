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
    this.paragraph,
    this.paragraphOffset,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> j) => ReadingProgress(
    bookId: j['bookId'] as int,
    chapter: j['chapter'] as int,
    scroll: (j['scroll'] as num).toDouble(),
    percent: (j['percent'] as num).toDouble(),
    minutesLeft: j['minutesLeft'] as int,
    lastOpened: DateTime.parse(j['lastOpened'] as String),
    paragraph: j['paragraph'] as int?,
    paragraphOffset: (j['paragraphOffset'] as num?)?.toDouble(),
  );

  final int bookId;
  final int chapter;

  final double scroll;

  final double percent;
  final int minutesLeft;
  final DateTime lastOpened;
  final int? paragraph;
  final double? paragraphOffset;

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapter': chapter,
    'scroll': scroll,
    'percent': percent,
    'minutesLeft': minutesLeft,
    'lastOpened': lastOpened.toIso8601String(),
    'paragraph': paragraph,
    'paragraphOffset': paragraphOffset,
  };
}
