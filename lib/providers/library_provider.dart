import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../services/book_repository.dart';

enum LoadState { loading, ready, error }

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._repo) {
    load();
  }

  final BookRepository _repo;
  List<Book> _books = const [];
  Map<int, Book> _index = const {};
  LoadState _state = LoadState.loading;
  String _query = '';
  String? _error;
  List<Book>? _filtered;

  LoadState get state => _state;
  List<Book> get books => _books;
  String get query => _query;

  /// Short description of the last load failure, if any.
  String? get error => _error;
  Book? byId(int id) => _index[id];

  /// Books matching the title/author search. Cached until the query or
  /// catalog changes, so rebuilds while scrolling stay cheap.
  List<Book> get filtered => _filtered ??= _computeFiltered();

  List<Book> _computeFiltered() {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _books;
    return _books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> load() async {
    if (_books.isEmpty) {
      _state = LoadState.loading;
      notifyListeners();
    }
    try {
      final list = await _repo.fetchBooks()
        ..sort(Book.compareNewestFirst);
      _books = list;
      _index = {for (final b in list) b.id: b};
      _filtered = null;
      _state = LoadState.ready;
      _error = null;
    } on Object catch (e, st) {
      debugPrint('Library load failed: $e\n$st');
      _error = e.toString();
      if (_books.isEmpty) _state = LoadState.error;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    final next = value.trim();
    if (next == _query) return;
    _query = next;
    _filtered = null;
    notifyListeners();
  }
}
