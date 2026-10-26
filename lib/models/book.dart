import 'package:flutter/foundation.dart';

import '../core/formatters.dart';

@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.added,
    required this.cover,
    required this.zip,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int,
        title: (json['title'] as String).trim(),
        author: (json['author'] as String).trim(),
        added: parseLongDate(json['added'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        cover: json['cover'] as String,
        zip: json['zip'] as String,
      );

  final int id;
  final String title;
  final String author;
  final DateTime added;
  final String cover;
  final String zip;

  /// Newest first; higher id wins when dates are equal.
  static int compareNewestFirst(Book a, Book b) {
    final byDate = b.added.compareTo(a.added);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }
}
