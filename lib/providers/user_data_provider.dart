import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/favorite_entry.dart';
import '../models/reading_progress.dart';
import '../services/local_store.dart';

class UserDataProvider extends ChangeNotifier {
  UserDataProvider(this._store) {
    _restore();
  }

  static const _favKey = 'favorites_v1';
  static const _progressKey = 'progress_v1';
  static const _finishedKey = 'finished_v1';

  final LocalStore _store;
  final Map<int, FavoriteEntry> _favs = {};
  final Map<int, ReadingProgress> _progress = {};
  final Set<int> _finished = {};

  void _restore() {
    final f = _store.readJson(_favKey);
    var migrated = false;
    if (f is List) {
      for (final e in f) {
        try {
          final map = e as Map<String, dynamic>;
          final x = FavoriteEntry.fromJson(map);
          _favs[x.bookId] = x;
          if (map['finished'] == true && _finished.add(x.bookId)) {
            migrated = true;
          }
        } on Object {
          continue;
        }
      }
    }
    final fin = _store.readJson(_finishedKey);
    if (fin is List) {
      for (final e in fin) {
        if (e is int) _finished.add(e);
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
    if (migrated) _saveFinished(notify: false);
  }

  List<FavoriteEntry> get favorites => List.unmodifiable(_favs.values);

  List<ReadingProgress> get recent =>
      _progress.values.toList()
        ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

  bool isFavorite(int id) => _favs.containsKey(id);
  bool isFinished(int id) => _finished.contains(id);
  FavoriteEntry? favoriteFor(int id) => _favs[id];
  ReadingProgress? progressFor(int id) => _progress[id];

  void toggleFavorite(int id) {
    if (_favs.remove(id) == null) {
      _favs[id] = FavoriteEntry(bookId: id, addedAt: DateTime.now());
    }
    _saveFavs();
  }

  void setFinished(int id, {required bool finished}) {
    final changed = finished ? _finished.add(id) : _finished.remove(id);
    if (changed) _saveFinished();
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
    final old = _progress[p.bookId];
    _progress[p.bookId] = p;
    _scheduleProgressWrite();
    final visibleChange =
        old == null ||
        old.chapter != p.chapter ||
        (old.percent * 100).round() != (p.percent * 100).round() ||
        old.minutesLeft != p.minutesLeft;
    if (visibleChange) notifyListeners();
  }

  Timer? _progressTimer;

  void _scheduleProgressWrite() {
    _progressTimer ??= Timer(const Duration(milliseconds: 500), flush);
  }

  void flush() {
    if (_progressTimer == null) return;
    _progressTimer!.cancel();
    _progressTimer = null;
    _store.writeJson(
      _progressKey,
      _progress.values.map((e) => e.toJson()).toList(),
    );
  }

  @override
  void dispose() {
    flush();
    super.dispose();
  }

  void _saveFavs() {
    _store.writeJson(_favKey, _favs.values.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  void _saveFinished({bool notify = true}) {
    _store.writeJson(_finishedKey, _finished.toList());
    if (notify) notifyListeners();
  }
}
