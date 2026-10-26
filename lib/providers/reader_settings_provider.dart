import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reader_prefs.dart';
import '../services/local_store.dart';

class ReaderSettingsProvider extends ChangeNotifier {
  ReaderSettingsProvider(this._store) {
    final json = _store.readJson(_key);
    if (json is Map<String, dynamic>) _prefs = ReaderPrefs.fromJson(json);
  }

  static const _key = 'reader_prefs_v1';
  final LocalStore _store;
  ReaderPrefs _prefs = const ReaderPrefs();
  Timer? _debounce;

  ReaderPrefs get prefs => _prefs;

  /// Applies immediately; persistence is debounced so sliders stay cheap.
  void update(ReaderPrefs next) {
    _prefs = next;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _store.writeJson(_key, next.toJson()));
  }

  void reset() => update(const ReaderPrefs());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
