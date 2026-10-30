import 'dart:convert';

import 'package:archive/archive.dart';
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

  bool _readFailed = false;
  bool _hasPendingWrites = false;
  String? _errorMessage;
  late final Future<void> _loaded;
  Future<void> _writes = Future.value();

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  String get retryLabel => _readFailed ? 'Retry loading' : 'Retry save';
  Note? byId(String id) => _notes[id];

  List<Note> get notes =>
      _notes.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _load() async {
    try {
      _notes.addAll(await _readNotes());
    } on Object catch (e) {
      _setLoadError(e);
    }
    _loading = false;
    notifyListeners();
  }

  Future<Map<String, Note>> _readNotes() async {
    final data = await _store.readFile(_file);
    final loaded = <String, Note>{};
    if (data is List) {
      var skipped = 0;
      for (final e in data) {
        try {
          final note = Note.fromJson(e as Map<String, dynamic>);
          loaded.putIfAbsent(note.id, () => note);
        } on Object {
          skipped++;
        }
      }
      if (skipped > 0) await _store.backupFile(_file);
    }
    return loaded;
  }

  void _setLoadError(Object error) {
    _readFailed = true;
    _errorMessage = 'Couldn\'t load your notes. Your existing file is preserved; retry loading before saving.';
    debugPrint('Loading notes failed: $error');
  }

  Future<void> retry() async {
    if (!_readFailed) {
      await _persist();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final loaded = await _readNotes();
      loaded.addAll(_notes);
      _notes
        ..clear()
        ..addAll(loaded);
      _readFailed = false;
      _errorMessage = null;
      _loading = false;
      notifyListeners();
      if (_hasPendingWrites) await _persist();
    } on Object catch (e) {
      _setLoadError(e);
      _loading = false;
      notifyListeners();
    }
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

  Future<int?> exportAllNotes() async {
    final snapshot = notes;
    if (snapshot.isEmpty) return 0;

    final archive = Archive();
    final usedNames = <String>{};
    for (final note in snapshot) {
      final heading = note.title.trim();
      final text = StringBuffer();
      if (heading.isNotEmpty) text.write('# $heading\n\n');
      text
        ..write(note.body.trimRight())
        ..write('\n');

      final safe = note.displayTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final baseName = safe.isEmpty ? 'Untitled' : safe;
      var fileName = '$baseName.md';
      var suffix = 2;
      while (!usedNames.add(fileName)) {
        fileName = '$baseName ($suffix).md';
        suffix++;
      }

      final bytes = utf8.encode(text.toString());
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }

    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export all notes',
      fileName: 'notes.zip',
      bytes: ZipEncoder().encodeBytes(archive),
    );
    return saved == null ? null : snapshot.length;
  }

  Future<void> _persist() {
    _hasPendingWrites = true;
    notifyListeners();
    _writes = _writes.then((_) async {
      await _loaded;
      if (_readFailed) return;
      try {
        final snapshot = _notes.values.map((n) => n.toJson()).toList();
        await _store.writeFile(_file, snapshot);
        _hasPendingWrites = false;
        _errorMessage = null;
      } on Object catch (e) {
        _errorMessage = 'Couldn\'t save your notes. Your edits are still available; retry to save them.';
        debugPrint('Saving notes failed: $e');
      }
      notifyListeners();
    });
    return _writes;
  }
}
