import 'package:flutter/foundation.dart';

@immutable
class FavoriteEntry {
  const FavoriteEntry({required this.bookId, required this.addedAt});

  /// Older versions stored a `finished` flag here; that now lives in
  /// [UserDataProvider] so a book can be finished without being a favorite.
  factory FavoriteEntry.fromJson(Map<String, dynamic> j) => FavoriteEntry(
        bookId: j['bookId'] as int,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );

  final int bookId;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'addedAt': addedAt.toIso8601String(),
      };
}
