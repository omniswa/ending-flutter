import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reader_prefs.dart';
import '../services/local_store.dart';

class ReaderSettingsProvider extends ChangeNotifier {
  ReaderSettingsProvider(this._store) {
    final json = _store.readJson(_key);
    if (json is Map<String, dynamic>) _prefs = ReaderPrefs.fromJson(json);
    _hintSeen = _store.readJson(_hintKey) == true;
  }

  static const _key = 'reader_prefs_v1';
  static const _hintKey = 'reader_swipe_hint_seen_v1';
  final LocalStore _store;
  ReaderPrefs _prefs = const ReaderPrefs();
  bool _hintSeen = false;
  Timer? _debounce;

  ReaderPrefs get prefs => _prefs;

  /// Whether the one-time "swipe to turn chapters" hint was already shown.
  bool get hintSeen => _hintSeen;

  void markHintSeen() {
    if (_hintSeen) return;
    _hintSeen = true;
    _store.writeJson(_hintKey, true);
  }

  /// Applies immediately; persistence is debounced so sliders stay cheap.
  void update(ReaderPrefs next) {
    _prefs = next;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _flush);
  }

  void _flush() {
    _debounce = null;
    _store.writeJson(_key, _prefs.toJson());
  }

  void reset() => update(const ReaderPrefs());

  @override
  void dispose() {
    // Don't lose a change made in the last 300 ms.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _flush();
    }
    super.dispose();
  }
}
