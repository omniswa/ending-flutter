import 'dart:convert';
import 'dart:io';

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

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, name));
  }

  Future<Object?> readFile(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } on Object {
      return null;
    }
  }

  /// Writes to a temp file then renames, so a crash never corrupts data.
  Future<void> writeFile(String name, Object value) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(f.path);
  }
}
