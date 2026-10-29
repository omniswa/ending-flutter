import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small persistence facade: JSON in SharedPreferences for small data,
/// atomic JSON files for larger data (notes).
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // corrupted entry: fall back to defaults
    }
  }

  /// Never throws: callers mostly fire-and-forget, and an unhandled async
  /// error here would otherwise go unnoticed. Returns whether it was saved.
  Future<bool> writeJson(String key, Object value) async {
    try {
      return await _prefs.setString(key, jsonEncode(value));
    } on Object catch (e) {
      debugPrint('Saving "$key" failed: $e');
      return false;
    }
  }

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, name));
  }

  /// Returns null when the file doesn't exist yet.
  ///
  /// If the file exists but isn't valid JSON, it is moved aside to
  /// `<name>.bad-<timestamp>` (so the data can still be recovered by hand)
  /// and null is returned. Real I/O errors are rethrown so callers can avoid
  /// overwriting data they failed to read.
  Future<Object?> readFile(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return null;
    final raw = await f.readAsString();
    try {
      return jsonDecode(raw);
    } on FormatException {
      await _moveAside(f);
      return null;
    }
  }

  /// Copies an existing file to `<name>.bak-<timestamp>`; no-op if missing.
  Future<void> backupFile(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return;
    await f.copy('${f.path}.bak-${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> _moveAside(File f) =>
      f.rename('${f.path}.bad-${DateTime.now().millisecondsSinceEpoch}');

  /// Writes to a temp file then renames, so a crash never corrupts data.
  Future<void> writeFile(String name, Object value) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(f.path);
  }
}
