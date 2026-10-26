import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/note.dart';
import '../services/local_store.dart';

class NotesProvider extends ChangeNotifier {
  NotesProvider(this._store) {
    _load();
  }

  static const _file = 'notes_v1.json';
  final LocalStore _store;
  final Map<String, Note> _notes = {};
  bool _loading = true;
  Future<void> _writes = Future.value(); // serialises disk writes

  bool get loading => _loading;
  Note? byId(String id) => _notes[id];

  /// Most recently edited first.
  List<Note> get notes =>
      _notes.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _load() async {
    final data = await _store.readFile(_file);
    if (data is List) {
      for (final e in data) {
        try {
          final n = Note.fromJson(e as Map<String, dynamic>);
          _notes[n.id] = n;
        } on Object {
          continue;
        }
      }
    }
    _loading = false;
    notifyListeners();
  }

  void save(Note note) {
    _notes[note.id] = note;
    _persist();
  }

  Note? delete(String id) {
    final removed = _notes.remove(id);
    if (removed != null) _persist();
    return removed;
  }

  /// Imports .txt / .md files as notes. Returns how many were imported.
  Future<int> importFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md'],
    );
    if (files.isEmpty) return 0;
    var count = 0;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final note = Note.create(
        id: '${DateTime.now().microsecondsSinceEpoch}_$count',
        title: p.basenameWithoutExtension(f.name),
        body: utf8.decode(bytes, allowMalformed: true),
      );
      _notes[note.id] = note;
      count++;
    }
    if (count > 0) _persist();
    return count;
  }

  void _persist() {
    notifyListeners();
    final snapshot = _notes.values.map((n) => n.toJson()).toList();
    _writes = _writes
        .then((_) => _store.writeFile(_file, snapshot))
        .catchError((Object e) => debugPrint('Saving notes failed: $e'));
  }
}
