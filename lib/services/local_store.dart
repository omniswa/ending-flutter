import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<bool> writeJson(String key, Object value) async {
    try {
      return await _prefs.setString(key, jsonEncode(value));
    } on Object catch (e) {
      debugPrint('Saving "$key" failed: $e');
      return false;
    }
  }

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, name));
  }

  Future<Object?> readFile(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return null;
    final raw = await f.readAsString();
    try {
      return jsonDecode(raw);
    } on FormatException {
      await _moveAside(f);
      throw FormatException(
        'The "$name" file contained invalid JSON and was moved aside.',
      );
    }
  }

  Future<void> backupFile(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return;
    await f.copy('${f.path}.bak-${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> _moveAside(File f) =>
      f.rename('${f.path}.bad-${DateTime.now().millisecondsSinceEpoch}');

  Future<void> writeFile(String name, Object value) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(f.path);
  }
}
