import 'package:flutter/foundation.dart';

import '../models/favorite_entry.dart';
import '../models/reading_progress.dart';
import '../services/local_store.dart';

/// Favorites + reading progress. Synchronous reads, persisted on every change.
class UserDataProvider extends ChangeNotifier {
  UserDataProvider(this._store) {
    _restore();
  }

  static const _favKey = 'favorites_v1';
  static const _progressKey = 'progress_v1';

  final LocalStore _store;
  final Map<int, FavoriteEntry> _favs = {};
  final Map<int, ReadingProgress> _progress = {};

  void _restore() {
    final f = _store.readJson(_favKey);
    if (f is List) {
      for (final e in f) {
        try {
          final x = FavoriteEntry.fromJson(e as Map<String, dynamic>);
          _favs[x.bookId] = x;
        } on Object {
          continue; // skip a corrupted record
        }
      }
    }
    final p = _store.readJson(_progressKey);
    if (p is List) {
      for (final e in p) {
        try {
          final x = ReadingProgress.fromJson(e as Map<String, dynamic>);
          _progress[x.bookId] = x;
        } on Object {
          continue;
        }
      }
    }
  }

  List<FavoriteEntry> get favorites => List.unmodifiable(_favs.values);

  /// Most recently opened first.
  List<ReadingProgress> get recent =>
      _progress.values.toList()..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

  bool isFavorite(int id) => _favs.containsKey(id);
  FavoriteEntry? favoriteFor(int id) => _favs[id];
  ReadingProgress? progressFor(int id) => _progress[id];

  void toggleFavorite(int id) {
    if (_favs.remove(id) == null) {
      _favs[id] = FavoriteEntry(bookId: id, addedAt: DateTime.now());
    }
    _saveFavs();
  }

  void setFinished(int id, {required bool finished}) {
    final e = _favs[id];
    if (e == null) return;
    _favs[id] = e.copyWith(finished: finished);
    _saveFavs();
  }

  FavoriteEntry? removeFavorite(int id) {
    final removed = _favs.remove(id);
    if (removed != null) _saveFavs();
    return removed;
  }

  void restoreFavorite(FavoriteEntry entry) {
    _favs[entry.bookId] = entry;
    _saveFavs();
  }

  void saveProgress(ReadingProgress p) {
    _progress[p.bookId] = p;
    _store.writeJson(_progressKey, _progress.values.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  void _saveFavs() {
    _store.writeJson(_favKey, _favs.values.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
