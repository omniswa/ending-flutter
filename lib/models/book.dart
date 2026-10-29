import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/formatters.dart';

@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.added,
    required this.cover,
    required this.file,
    required this.isEpub,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final epub = json['epub'];
    final file = json['file'] ?? epub ?? json['zip'];
    if (file is! String || file.trim().isEmpty) {
      throw const FormatException(
        'Book entry must include a file, epub, or zip path.',
      );
    }
    final resolvedFile = AppConfig.resolve(file);

    return Book(
      id: json['id'] as int,
      title: (json['title'] as String).trim(),
      author: (json['author'] as String).trim(),
      added:
          parseLongDate(json['added'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      // Catalog paths may be relative to the books.json location.
      cover: AppConfig.resolve(json['cover'] as String),
      file: resolvedFile,
      isEpub:
          epub == file ||
          Uri.parse(resolvedFile).path.toLowerCase().endsWith('.epub'),
    );
  }

  final int id;
  final String title;
  final String author;
  final DateTime added;
  final String cover;
  final String file;
  final bool isEpub;

  /// Newest first; higher id wins when dates are equal.
  static int compareNewestFirst(Book a, Book b) {
    final byDate = b.added.compareTo(a.added);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }
}
