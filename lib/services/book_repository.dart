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

class BookRepository {
  BookRepository(this._store, {http.Client? client}) : _client = client ?? http.Client();

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

  List<Book> _parse(Object? json) => (json as List)
      .map((e) => Book.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<Directory> _bookDir(Book book) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'books', '${book.id}'));
  }

  /// Returns chapter texts in order, downloading and unzipping on first use.
  Future<List<String>> loadChapters(Book book) async {
    final dir = await _bookDir(book);
    var files = _chapterFiles(dir);
    if (files.isEmpty) {
      await _download(book, dir);
      files = _chapterFiles(dir);
    }
    if (files.isEmpty) throw const FormatException('This book has no chapters.');
    return Future.wait(files.map((f) => f.readAsString()));
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
    final res = await _client.get(_resolve(book.zip)).timeout(const Duration(minutes: 2));
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }
    final chapters = await compute(_extractChapters, res.bodyBytes);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    try {
      for (final e in chapters.entries) {
        await File(p.join(dir.path, e.key)).writeAsString(e.value, flush: true);
      }
    } on Object {
      await dir.delete(recursive: true); // never leave a half-written book
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
    if (!RegExp(r'^\d+\.txt$').hasMatch(name)) continue;
    out[name] = utf8.decode(f.content as List<int>, allowMalformed: true);
  }
  return out;
}
