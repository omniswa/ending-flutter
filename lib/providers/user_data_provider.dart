import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/favorite_entry.dart';
import '../models/reader_highlight.dart';
import '../models/reading_progress.dart';
import '../services/local_store.dart';

class UserDataProvider extends ChangeNotifier {
  UserDataProvider(this._store) {
    _restore();
  }

  static const _favKey = 'favorites_v1';
  static const _progressKey = 'progress_v1';
  static const _finishedKey = 'finished_v1';
  static const _highlightsKey = 'reader_highlights_v1';

  final LocalStore _store;
  final Map<int, FavoriteEntry> _favs = {};
  final Map<int, ReadingProgress> _progress = {};
  final Map<String, ReaderHighlight> _highlights = {};
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
    final h = _store.readJson(_highlightsKey);
    if (h is List) {
      var removedOverlap = false;
      for (final e in h) {
        try {
          final highlight = ReaderHighlight.fromJson(e as Map<String, dynamic>);
          if (highlight.start >= 0 &&
              highlight.end > highlight.start &&
              highlight.quote.isNotEmpty &&
              !_highlights.values.any(
                (saved) =>
                    saved.bookId == highlight.bookId &&
                    saved.chapter == highlight.chapter &&
                    saved.paragraph == highlight.paragraph &&
                    saved.start < highlight.end &&
                    saved.end > highlight.start,
              )) {
            _highlights[highlight.id] = highlight;
          } else {
            removedOverlap = true;
          }
        } on Object {
          continue;
        }
      }
      if (removedOverlap) _saveHighlights(notify: false);
    }
    if (migrated) {
      _saveFinished(notify: false);
      _saveFavs(notify: false);
    }
  }

  List<FavoriteEntry> get favorites => List.unmodifiable(_favs.values);

  List<ReadingProgress> get recent =>
      _progress.values.toList()
        ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

  bool isFavorite(int id) => _favs.containsKey(id);
  bool isFinished(int id) => _finished.contains(id);
  FavoriteEntry? favoriteFor(int id) => _favs[id];
  ReadingProgress? progressFor(int id) => _progress[id];

  List<ReaderHighlight> highlightsFor(int bookId, int chapter, int paragraph) =>
      _highlights.values
          .where(
            (highlight) =>
                highlight.bookId == bookId &&
                highlight.chapter == chapter &&
                highlight.paragraph == paragraph,
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<ReaderHighlight> highlightsForBook(int bookId) =>
      _highlights.values
          .where((highlight) => highlight.bookId == bookId)
          .toList()
        ..sort((a, b) {
          final chapterOrder = a.chapter.compareTo(b.chapter);
          if (chapterOrder != 0) return chapterOrder;
          final paragraphOrder = a.paragraph.compareTo(b.paragraph);
          return paragraphOrder != 0
              ? paragraphOrder
              : a.start.compareTo(b.start);
        });

  bool hasHighlight(ReaderHighlight highlight) =>
      _highlights.containsKey(highlight.id);

  bool toggleHighlight(ReaderHighlight highlight) {
    if (_highlights.remove(highlight.id) != null) {
      _saveHighlights();
      return true;
    }
    final overlaps = _highlights.values.any(
      (saved) =>
          saved.bookId == highlight.bookId &&
          saved.chapter == highlight.chapter &&
          saved.paragraph == highlight.paragraph &&
          saved.start < highlight.end &&
          saved.end > highlight.start,
    );
    if (overlaps) return false;
    _highlights[highlight.id] = highlight;
    _saveHighlights();
    return true;
  }

  void _saveHighlights({bool notify = true}) {
    _store.writeJson(
      _highlightsKey,
      _highlights.values.map((entry) => entry.toJson()).toList(),
    );
    if (notify) notifyListeners();
  }

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

  void _saveFavs({bool notify = true}) {
    _store.writeJson(_favKey, _favs.values.map((e) => e.toJson()).toList());
    if (notify) notifyListeners();
  }

  void _saveFinished({bool notify = true}) {
    _store.writeJson(_finishedKey, _finished.toList());
    if (notify) notifyListeners();
  }
}
