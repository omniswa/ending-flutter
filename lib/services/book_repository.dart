import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../models/book.dart';
import 'local_store.dart';

class BookContent {
  const BookContent(this.chapters, this.titles);
  final List<String> chapters;
  final List<String?> titles; // same length as chapters; null = no title
}

class BookRepository {
  BookRepository(this._store, {http.Client? client})
    : _client = client ?? http.Client();

  static const _cacheKey = 'books_index_cache';
  final LocalStore _store;
  final http.Client _client;

  Uri _resolve(String path) => Uri.parse(AppConfig.baseUrl).resolve(path);

  /// Fetches the catalog; falls back to the last cached copy when offline.
  Future<List<Book>> fetchBooks() async {
    try {
      final res = await _client
          .get(_resolve(AppConfig.booksIndex))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) {
        throw HttpException('Catalog request failed (${res.statusCode})');
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final books = _parse(json);
      await _store.writeJson(_cacheKey, json as Object);
      return books;
    } on Object {
      final cached = _store.readJson(_cacheKey);
      if (cached != null) return _parse(cached);
      rethrow;
    }
  }

  List<Book> _parse(Object? json) {
    final out = <Book>[];
    for (final e in json as List) {
      try {
        out.add(Book.fromJson(e as Map<String, dynamic>));
      } on Object catch (err) {
        debugPrint('Skipping bad book entry: $err\n$e');
      }
    }
    return out;
  }

  Future<Directory> _bookDir(Book book) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'books', '${book.id}'));
  }

  /// Returns chapter texts + titles in order, downloading on first use.
  Future<BookContent> loadContent(Book book) async {
    final dir = await _bookDir(book);
    if (_chapterFiles(dir).isEmpty) await _download(book, dir);

    final chapters = <String>[];
    final titles = <String?>[];

    // 1) Prefer manifest.json (order + titles).
    for (final e in _readManifest(dir) ?? const []) {
      final f = File(p.join(dir.path, e.file));
      if (!f.existsSync()) continue;
      chapters.add(await f.readAsString());
      titles.add(e.title == null || e.title!.isEmpty ? null : e.title);
    }

    // 2) Fallback: numbered files (1.txt, 2.txt, ...).
    if (chapters.isEmpty) {
      for (final f in _chapterFiles(dir)) {
        chapters.add(await f.readAsString());
        titles.add(null);
      }
    }

    if (chapters.isEmpty)
      throw const FormatException('This book has no chapters.');
    return BookContent(chapters, titles);
  }

  List<({String file, String? title})>? _readManifest(Directory dir) {
    final f = File(p.join(dir.path, 'manifest.json'));
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final list = (json['chapters'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return (
          file: p.basename(m['file'] as String), // basename blocks "../" tricks
          title: (m['title'] as String?)?.trim(),
        );
      }).toList();
      return list.isEmpty ? null : list;
    } on Object {
      return null; // malformed manifest: fall back to numbered files
    }
  }

  List<File> _chapterFiles(Directory dir) {
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'^\d+\.txt$').hasMatch(p.basename(f.path)))
        .toList();
    int n(File f) => int.parse(p.basenameWithoutExtension(f.path));
    files.sort((a, b) => n(a).compareTo(n(b)));
    return files;
  }

  Future<void> _download(Book book, Directory dir) async {
    final res = await _client
        .get(_resolve(book.zip))
        .timeout(const Duration(minutes: 2));
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }
    final chapters = await compute(_extractChapters, res.bodyBytes);
    // Write into a sibling temp dir and rename, so a crash or kill mid-write
    // can never leave a truncated book that looks complete on the next open.
    final tmp = Directory('${dir.path}.tmp');
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    try {
      for (final e in chapters.entries) {
        await File(p.join(tmp.path, e.key)).writeAsString(e.value, flush: true);
      }
      if (dir.existsSync()) await dir.delete(recursive: true);
      await tmp.rename(dir.path);
    } on Object {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
      rethrow;
    }
  }
}

/// Runs in a background isolate.
Map<String, String> _extractChapters(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final out = <String, String>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final name = p.basename(f.name);
    if (name != 'manifest.json' && !RegExp(r'^\d+\.txt$').hasMatch(name))
      continue;
    out[name] = utf8.decode(f.content as List<int>, allowMalformed: true);
  }
  return out;
}
