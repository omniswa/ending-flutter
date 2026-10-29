import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

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

  void dispose() => _client.close();

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

  final Map<int, Future<BookContent>> _inFlight = {};

  /// Returns chapter texts + titles in order, downloading on first use.
  ///
  /// Concurrent calls for the same book share a single download. [refresh]
  /// forces a re-download; if that fails and a local copy exists, the local
  /// copy is used instead of surfacing an error.
  Future<BookContent> loadContent(Book book, {bool refresh = false}) {
    final running = _inFlight[book.id];
    if (running != null) return running;
    final future = _loadContent(book, refresh: refresh).whenComplete(() {
      // Block body on purpose: returning remove()'s value (this same future)
      // would make whenComplete wait on itself.
      _inFlight.remove(book.id);
    });
    return _inFlight[book.id] = future;
  }

  Future<bool> isDownloaded(Book book) async =>
      _hasContent(await _bookDir(book));

  /// Deletes the downloaded copy (reading progress is kept).
  Future<void> deleteDownload(Book book) async {
    await _inFlight[book.id]?.catchError((_) => const BookContent([], []));
    final dir = await _bookDir(book);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<BookContent> _loadContent(Book book, {required bool refresh}) async {
    final dir = await _bookDir(book);
    final hasLocal = _hasContent(dir);
    final source = _readSource(dir);
    // A changed source URL in the catalog means the book was republished.
    final needsDownload =
        !hasLocal || refresh || (source != null && source != book.file);
    if (needsDownload) {
      try {
        await _download(book, dir);
      } on Object catch (e) {
        if (!hasLocal) rethrow;
        debugPrint('Update for "${book.title}" failed, using local copy: $e');
      }
    }
    return _readContent(dir);
  }

  bool _hasContent(Directory dir) {
    if (_chapterFiles(dir).isNotEmpty) return true;
    final manifest = _readManifest(dir);
    return manifest != null &&
        manifest.any((e) => File(p.join(dir.path, e.file)).existsSync());
  }

  static const _sourceFile = '.source';

  String? _readSource(Directory dir) {
    final f = File(p.join(dir.path, _sourceFile));
    try {
      return f.existsSync() ? f.readAsStringSync().trim() : null;
    } on Object {
      return null;
    }
  }

  Future<BookContent> _readContent(Directory dir) async {
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

    if (chapters.isEmpty) {
      throw const FormatException('This book has no chapters.');
    }
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
        .get(_resolve(book.file))
        .timeout(const Duration(minutes: 2));
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }
    final chapters = await compute(_extractBook, (res.bodyBytes, book.isEpub));
    // Write into a sibling temp dir and rename, so a crash or kill mid-write
    // can never leave a truncated book that looks complete on the next open.
    final tmp = Directory('${dir.path}.tmp');
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    try {
      for (final e in chapters.entries) {
        await File(p.join(tmp.path, e.key)).writeAsString(e.value, flush: true);
      }
      // Remember which source this copy came from, to detect republished books.
      await File(p.join(tmp.path, _sourceFile))
          .writeAsString(book.file, flush: true);
      if (dir.existsSync()) await dir.delete(recursive: true);
      await tmp.rename(dir.path);
    } on Object {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
      rethrow;
    }
  }
}

/// Runs in a background isolate.
Map<String, String> _extractBook((Uint8List, bool) input) {
  final (bytes, isEpub) = input;
  final archive = ZipDecoder().decodeBytes(bytes);
  if (isEpub) return _extractEpub(archive);

  final out = <String, String>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final name = p.basename(f.name);
    // Keep the manifest and any .txt chapter (manifest entries may use
    // names other than 1.txt, 2.txt...). Skip hidden/junk files.
    final keep =
        name == 'manifest.json' ||
        (name.endsWith('.txt') && !name.startsWith('.'));
    if (!keep) continue;
    out[name] = utf8.decode(f.content as List<int>, allowMalformed: true);
  }
  return out;
}

Map<String, String> _extractEpub(Archive archive) {
  final files = <String, Uint8List>{};
  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final path = _normalizeEpubPath(entry.name);
    if (path != null) {
      files[path] = Uint8List.fromList(entry.content as List<int>);
    }
  }

  final container = files['META-INF/container.xml'];
  if (container == null) {
    throw const FormatException('EPUB is missing META-INF/container.xml.');
  }
  final containerXml = XmlDocument.parse(
    utf8.decode(container, allowMalformed: true),
  );
  final rootfiles = containerXml.findAllElements('rootfile', namespaceUri: '*');
  final rootfile = rootfiles.isEmpty ? null : rootfiles.first;
  final packagePath = rootfile?.getAttribute('full-path');
  if (packagePath == null || packagePath.isEmpty) {
    throw const FormatException('EPUB does not declare a package document.');
  }

  final normalizedPackagePath = _normalizeEpubPath(packagePath);
  if (normalizedPackagePath == null) {
    throw const FormatException('EPUB package path is invalid.');
  }
  final packageBytes = files[normalizedPackagePath];
  if (packageBytes == null) {
    throw const FormatException('EPUB package document was not found.');
  }
  final packageXml = XmlDocument.parse(
    utf8.decode(packageBytes, allowMalformed: true),
  );
  final manifest = <String, ({String href, String mediaType})>{};
  for (final item in packageXml.findAllElements('item', namespaceUri: '*')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = (
      href: href,
      mediaType: item.getAttribute('media-type') ?? '',
    );
  }

  final basePath = p.posix.dirname(packagePath);
  final chapterTexts = <String>[];
  final titles = <String?>[];
  for (final itemRef in packageXml.findAllElements(
    'itemref',
    namespaceUri: '*',
  )) {
    final id = itemRef.getAttribute('idref');
    final item = id == null ? null : manifest[id];
    if (item == null ||
        (!item.mediaType.contains('xhtml') &&
            !item.href.toLowerCase().endsWith('.xhtml') &&
            !item.href.toLowerCase().endsWith('.html'))) {
      continue;
    }
    final path = _normalizeEpubPath(
      p.posix.join(basePath, Uri.parse(item.href).path),
    );
    final chapter = path == null ? null : files[path];
    if (chapter == null) continue;

    final document = XmlDocument.parse(
      utf8.decode(chapter, allowMalformed: true),
    );
    final bodies = document.findAllElements('body', namespaceUri: '*');
    final body = bodies.isEmpty ? document.rootElement : bodies.first;
    final text = _epubText(body);
    if (text.isEmpty) continue;
    final heading = document
        .findAllElements('*', namespaceUri: '*')
        .where((element) => RegExp(r'^h[1-6]$').hasMatch(element.name.local))
        .map((element) => _epubText(element))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    chapterTexts.add(text);
    titles.add(heading.isEmpty ? null : heading);
  }

  if (chapterTexts.isEmpty) {
    throw const FormatException('This EPUB has no readable chapters.');
  }
  final out = <String, String>{};
  final entries = <Map<String, String?>>[];
  for (var i = 0; i < chapterTexts.length; i++) {
    final name = '${i + 1}.txt';
    out[name] = chapterTexts[i];
    entries.add({'file': name, 'title': titles[i]});
  }
  out['manifest.json'] = jsonEncode({'chapters': entries});
  return out;
}

String? _normalizeEpubPath(String path) {
  final segments = <String>[];
  for (final segment in path.replaceAll('\\', '/').split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

String _epubText(XmlNode node) {
  final output = StringBuffer();
  const blockElements = {
    'address',
    'article',
    'blockquote',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'ol',
    'p',
    'section',
    'table',
    'tr',
    'ul',
  };

  void visit(XmlNode current) {
    if (current is XmlText) {
      output.write(current.value);
    } else if (current is XmlElement) {
      final name = current.name.local.toLowerCase();
      if (name == 'script' || name == 'style' || name == 'nav') return;
      final isBlock = blockElements.contains(name);
      if (isBlock) output.write('\n\n');
      if (name == 'br') {
        output.write('\n');
      } else {
        for (final child in current.children) {
          visit(child);
        }
      }
      if (isBlock) output.write('\n\n');
    } else {
      for (final child in current.children) {
        visit(child);
      }
    }
  }

  visit(node);
  return output
      .toString()
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .join('\n\n');
}
