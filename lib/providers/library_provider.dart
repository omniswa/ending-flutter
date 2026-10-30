import 'dart:async';

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
  Object? _error;
  String _query = '';
  List<Book>? _filtered;
  final Set<int> _downloaded = {};
  final Set<int> _checkingDownloads = {};
  final Set<int> _downloading = {};

  LoadState get state => _state;
  List<Book> get books => _books;
  String? get errorMessage => _error?.toString();
  String get query => _query;
  Book? byId(int id) => _index[id];
  bool isDownloaded(int id) => _downloaded.contains(id);
  bool isCheckingDownload(int id) => _checkingDownloads.contains(id);
  bool isDownloading(int id) => _downloading.contains(id);

  List<Book> get filtered => _filtered ??= _computeFiltered();

  List<Book> _computeFiltered() {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _books;
    return _books
        .where(
          (b) =>
              b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  Future<void> load() async {
    _error = null;
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
      unawaited(_refreshAllDownloadStatuses(list));
    } on Object catch (e, st) {
      _error = e;
      debugPrint('Library load failed: $e\n$st');
      if (_books.isEmpty) _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> _refreshAllDownloadStatuses(List<Book> list) async {
    final results = await Future.wait(
      list.map((book) async {
        try {
          return (id: book.id, downloaded: await _repo.isDownloaded(book));
        } on Object catch (error, stack) {
          debugPrint(
            'Checking offline status for "${book.title}" failed: $error\n$stack',
          );
          return null;
        }
      }),
    );
    for (final r in results) {
      if (r == null || _downloading.contains(r.id)) continue;
      if (r.downloaded) {
        _downloaded.add(r.id);
      } else {
        _downloaded.remove(r.id);
      }
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refreshDownloadStatus(Book book) async {
    _checkingDownloads.add(book.id);
    notifyListeners();
    try {
      final downloaded = await _repo.isDownloaded(book);
      if (!_downloading.contains(book.id)) {
        if (downloaded) {
          _downloaded.add(book.id);
        } else {
          _downloaded.remove(book.id);
        }
      }
    } finally {
      _checkingDownloads.remove(book.id);
      notifyListeners();
    }
  }

  Future<void> download(Book book) async {
    if (_downloading.contains(book.id)) return;
    _downloading.add(book.id);
    notifyListeners();
    try {
      await _repo.loadContent(book);
      _downloaded.add(book.id);
    } finally {
      _downloading.remove(book.id);
      notifyListeners();
    }
  }

  void setQuery(String value) {
    final next = value.trim();
    if (next == _query) return;
    _query = next;
    _filtered = null;
    notifyListeners();
  }
}
