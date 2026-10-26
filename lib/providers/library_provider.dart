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
  String? _author;

  LoadState get state => _state;
  List<Book> get books => _books;
  String get query => _query;
  String? get author => _author;
  bool get hasFilters => _query.isNotEmpty || _author != null;
  Book? byId(int id) => _index[id];

  List<String> get authors => _books.map((b) => b.author).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  /// Books matching the title/author search and the author filter.
  List<Book> get filtered {
    final q = _query.toLowerCase();
    return _books
        .where((b) =>
            (_author == null || b.author == _author) &&
            (q.isEmpty ||
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q)))
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
      _state = LoadState.ready;
    } on Object catch (e, st) {
      debugPrint('Library load failed: $e\n$st');
      if (_books.isEmpty) _state = LoadState.error;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value.trim();
    notifyListeners();
  }

  void setAuthor(String? value) {
    _author = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _author = null;
    notifyListeners();
  }
}
