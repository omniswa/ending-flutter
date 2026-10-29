import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/note.dart';
import '../services/local_store.dart';

enum NoteExportFormat {
  text('Plain text', '.txt'),
  markdown('Markdown', '.md');

  const NoteExportFormat(this.label, this.extension);
  final String label;
  final String extension;
}

class NotesProvider extends ChangeNotifier {
  NotesProvider(this._store) {
    _loaded = _load();
  }

  static const _file = 'notes_v1.json';
  final LocalStore _store;
  final Map<String, Note> _notes = {};
  bool _loading = true;

  /// True when the notes file exists but couldn't be read. Writing is then
  /// disabled for the session so we never overwrite data we failed to load.
  bool _readFailed = false;
  late final Future<void> _loaded;
  Future<void> _writes = Future.value(); // serialises disk writes

  bool get loading => _loading;
  Note? byId(String id) => _notes[id];

  /// Most recently edited first.
  List<Note> get notes =>
      _notes.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _load() async {
    try {
      final data = await _store.readFile(_file);
      if (data is List) {
        var skipped = 0;
        for (final e in data) {
          try {
            final n = Note.fromJson(e as Map<String, dynamic>);
            // Anything created while loading is newer; keep it.
            _notes.putIfAbsent(n.id, () => n);
          } on Object {
            skipped++;
          }
        }
        // The next save drops unreadable entries, so keep a copy first.
        if (skipped > 0) await _store.backupFile(_file);
      }
    } on Object catch (e) {
      _readFailed = true;
      debugPrint('Loading notes failed: $e');
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

  /// Saves one note to a file the person picks. Returns false if they cancel.
  Future<bool> exportNote({
    required String title,
    required String body,
    required NoteExportFormat format,
  }) async {
    final heading = title.trim();
    final text = StringBuffer();
    if (heading.isNotEmpty) {
      text.write(format == NoteExportFormat.markdown ? '# $heading' : heading);
      text.write('\n\n');
    }
    text.write(body.trimRight());
    text.write('\n');

    final safe = heading
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final name = safe.isEmpty ? 'note' : safe;

    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export note',
      fileName: '$name${format.extension}',
      bytes: Uint8List.fromList(utf8.encode(text.toString())),
    );
    return saved != null;
  }

  void _persist() {
    notifyListeners();
    // Wait for the initial load, then snapshot at write time so the file
    // always reflects the latest state (and includes the loaded notes).
    _writes = _writes
        .then((_) => _loaded)
        .then((_) async {
          if (_readFailed) return;
          final snapshot = _notes.values.map((n) => n.toJson()).toList();
          await _store.writeFile(_file, snapshot);
        })
        .catchError((Object e) => debugPrint('Saving notes failed: $e'));
  }
}
