import 'package:flutter/foundation.dart';

@immutable
class ReaderHighlight {
  const ReaderHighlight({
    required this.bookId,
    required this.chapter,
    required this.paragraph,
    required this.start,
    required this.end,
    required this.quote,
  });

  factory ReaderHighlight.fromJson(Map<String, dynamic> json) =>
      ReaderHighlight(
        bookId: json['bookId'] as int,
        chapter: json['chapter'] as int,
        paragraph: json['paragraph'] as int,
        start: json['start'] as int,
        end: json['end'] as int,
        quote: json['quote'] as String,
      );

  final int bookId;
  final int chapter;
  final int paragraph;
  final int start;
  final int end;
  final String quote;

  String get id => '$bookId:$chapter:$paragraph:$start:$end';

  @override
  bool operator ==(Object other) =>
      other is ReaderHighlight &&
      other.bookId == bookId &&
      other.chapter == chapter &&
      other.paragraph == paragraph &&
      other.start == start &&
      other.end == end &&
      other.quote == quote;

  @override
  int get hashCode =>
      Object.hash(bookId, chapter, paragraph, start, end, quote);

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapter': chapter,
    'paragraph': paragraph,
    'start': start,
    'end': end,
    'quote': quote,
  };
}
