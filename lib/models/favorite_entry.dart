import 'package:flutter/foundation.dart';

@immutable
class FavoriteEntry {
  const FavoriteEntry({
    required this.bookId,
    required this.addedAt,
    this.finished = false,
  });

  factory FavoriteEntry.fromJson(Map<String, dynamic> j) => FavoriteEntry(
        bookId: j['bookId'] as int,
        addedAt: DateTime.parse(j['addedAt'] as String),
        finished: j['finished'] as bool? ?? false,
      );

  final int bookId;
  final DateTime addedAt;
  final bool finished;

  FavoriteEntry copyWith({bool? finished}) => FavoriteEntry(
        bookId: bookId,
        addedAt: addedAt,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'addedAt': addedAt.toIso8601String(),
        'finished': finished,
      };
}
