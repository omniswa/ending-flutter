import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../core/config.dart';
import '../models/book.dart';
import 'local_store.dart';

class BookContent {
  const BookContent(this.chapters, this.titles, {this.refreshFailed = false});
  final List<String> chapters;
  final List<String?> titles;
  final bool refreshFailed;
}

class BookCatalog {
  const BookCatalog(this.books, {this.refreshFailed = false});
  final List<Book> books;
  final bool refreshFailed;
}

class BookRepository {
  BookRepository(this._store, {http.Client? client})
    : _client = client ?? http.Client();

  static const _legacyCacheKey = 'books_index_cache';
  static const _cacheFile = 'books_index_cache.json';
  static const _epubExtractionVersion = '2';
  static const _epubExtractionVersionFile = '.epub-extraction-version';
  final LocalStore _store;
  final http.Client _client;

  void dispose() => _client.close();

  Uri _resolve(String path) => Uri.parse(AppConfig.baseUrl).resolve(path);

  Future<BookCatalog> fetchBooks() async {
    late final List<Book> books;
    late final Object json;
    try {
      final res = await _client
          .get(_resolve(AppConfig.booksIndex))
          .timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) {
        throw HttpException('Catalog request failed (${res.statusCode})');
      }
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Object;
      books = _parse(json);
    } on Object {
      final cached = await _readCachedCatalog();
      if (cached != null) {
        return BookCatalog(cached, refreshFailed: true);
      }
      rethrow;
    }
    try {
      await _store.writeFile(_cacheFile, json);
      await _removeLegacyCache();
    } on Object catch (error, stackTrace) {
      debugPrint('Saving book catalog cache failed: $error\n$stackTrace');
    }
    return BookCatalog(books);
  }

  Future<List<Book>?> _readCachedCatalog() async {
    final cached = await _store.readFile(_cacheFile);
    if (cached != null) {
      await _removeLegacyCache();
      return _parse(cached);
    }

    final legacy = _store.readJson(_legacyCacheKey);
    if (legacy == null) return null;
    try {
      await _store.writeFile(_cacheFile, legacy);
      await _removeLegacyCache();
    } on Object catch (error, stackTrace) {
      debugPrint('Migrating book catalog cache failed: $error\n$stackTrace');
    }
    return _parse(legacy);
  }

  Future<void> _removeLegacyCache() async {
    try {
      await _store.remove(_legacyCacheKey);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Removing legacy book catalog cache failed: $error\n$stackTrace',
      );
    }
  }

  List<Book> _parse(Object? json) {
    final out = <Book>[];
    final ids = <int>{};
    for (final e in json as List) {
      try {
        final book = Book.fromJson(e as Map<String, dynamic>);
        if (!ids.add(book.id)) {
          debugPrint('Skipping duplicate book ID ${book.id}: $e');
          continue;
        }
        out.add(book);
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

  Future<BookContent> loadContent(Book book, {bool refresh = false}) {
    final running = _inFlight[book.id];
    if (running != null) return running;
    final future = _loadContent(book, refresh: refresh).whenComplete(() {
      _inFlight.remove(book.id);
    });
    return _inFlight[book.id] = future;
  }

  Future<void> downloadBook(Book book) async {
    await loadContent(book);
  }

  Future<bool> isDownloaded(Book book) async {
    final dir = await _bookDir(book);
    if (!await dir.exists()) return false;

    final entries = await dir.list().toList();
    final files = entries.whereType<File>().map(
      (file) => p.basename(file.path),
    );
    final fileNames = files.toSet();
    if (fileNames.any((name) => RegExp(r'^\d+\.txt$').hasMatch(name))) {
      return true;
    }

    if (!fileNames.contains('manifest.json')) return false;
    try {
      final manifest = jsonDecode(
        await File(p.join(dir.path, 'manifest.json')).readAsString(),
      ) as Map<String, dynamic>;
      final chapters = manifest['chapters'] as List;
      return chapters.any((entry) {
        final file = (entry as Map<String, dynamic>)['file'] as String;
        return fileNames.contains(p.basename(file));
      });
    } on Object {
      return false;
    }
  }

  Future<void> deleteDownload(Book book) async {
    await _inFlight[book.id]?.catchError((_) => const BookContent([], []));
    final dir = await _bookDir(book);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<BookContent> _loadContent(Book book, {required bool refresh}) async {
    final dir = await _bookDir(book);
    final refreshFailed = await _ensureDownloaded(book, dir, refresh: refresh);
    final content = await _readContent(dir);
    if (!refreshFailed) return content;
    return BookContent(content.chapters, content.titles, refreshFailed: true);
  }

  Future<bool> _ensureDownloaded(
    Book book,
    Directory dir, {
    required bool refresh,
  }) async {
    final hasLocal = _hasContent(dir);
    final source = _readSource(dir);
    final epubExtractionVersionFile = File(
      p.join(dir.path, _epubExtractionVersionFile),
    );
    final epubExtractionVersion = epubExtractionVersionFile.existsSync()
        ? epubExtractionVersionFile.readAsStringSync().trim()
        : null;
    final needsDownload =
        !hasLocal ||
        refresh ||
        (source != null && source != book.file) ||
        (book.isEpub && epubExtractionVersion != _epubExtractionVersion);
    if (needsDownload) {
      try {
        await _download(book, dir);
      } on Object catch (e) {
        if (!hasLocal) rethrow;
        debugPrint('Update for "${book.title}" failed, using local copy: $e');
        return true;
      }
    }
    return false;
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

    for (final e in _readManifest(dir) ?? const []) {
      final f = File(p.join(dir.path, e.file));
      if (!f.existsSync()) continue;
      chapters.add(await f.readAsString());
      titles.add(e.title == null || e.title!.isEmpty ? null : e.title);
    }

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
          file: p.basename(m['file'] as String),
          title: (m['title'] as String?)?.trim(),
        );
      }).toList();
      return list.isEmpty ? null : list;
    } on Object {
      return null;
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
    final tmp = Directory('${dir.path}.tmp');
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    var movedOld = false;
    try {
      for (final e in chapters.entries) {
        await File(p.join(tmp.path, e.key)).writeAsString(e.value, flush: true);
      }
      await File(p.join(tmp.path, _sourceFile))
          .writeAsString(book.file, flush: true);
      if (book.isEpub) {
        await File(p.join(tmp.path, _epubExtractionVersionFile))
            .writeAsString(_epubExtractionVersion, flush: true);
      }
      final old = Directory('${dir.path}.old');
      if (old.existsSync()) {
        if (dir.existsSync()) {
          await old.delete(recursive: true);
        } else {
          await old.rename(dir.path);
        }
      }
      if (dir.existsSync()) {
        await dir.rename(old.path);
        movedOld = true;
      }
      await tmp.rename(dir.path);
      if (movedOld) await old.delete(recursive: true);
    } on Object catch (error, stackTrace) {
      try {
        final old = Directory('${dir.path}.old');
        if (movedOld && old.existsSync()) {
          if (dir.existsSync()) await dir.delete(recursive: true);
          await old.rename(dir.path);
        }
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      } on Object catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'Download failed: $error. Rollback failed: $rollbackError',
          ),
          rollbackStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

Map<String, String> _extractBook((Uint8List, bool) input) {
  final (bytes, isEpub) = input;
  final archive = ZipDecoder().decodeBytes(bytes);
  if (isEpub) return _extractEpub(archive);

  final out = <String, String>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final name = p.basename(f.name);
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
    entityMapping: const XmlDefaultEntityMapping.html5(),
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
    entityMapping: const XmlDefaultEntityMapping.html5(),
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
  var skippedChapters = 0;
  for (final itemRef in packageXml.findAllElements(
    'itemref',
    namespaceUri: '*',
  )) {
    if (itemRef.getAttribute('linear')?.toLowerCase() == 'no') continue;
    final id = itemRef.getAttribute('idref');
    final item = id == null ? null : manifest[id];
    if (item == null ||
        (!item.mediaType.contains('xhtml') &&
            !item.href.toLowerCase().endsWith('.xhtml') &&
            !item.href.toLowerCase().endsWith('.html'))) {
      continue;
    }
    final path = _resolveEpubHref(basePath, item.href);
    if (path == null) continue;
    final chapter = files[path];
    if (chapter == null) continue;

    final html.Document document;
    try {
      document = html_parser.parse(
        _stripBom(utf8.decode(chapter, allowMalformed: true)),
      );
    } on Object catch (e) {
      skippedChapters++;
      debugPrint('Unable to parse EPUB chapter "$path": $e');
      continue;
    }
    final body = document.body;
    if (body == null) {
      skippedChapters++;
      debugPrint('Unable to parse EPUB chapter "$path": no document body.');
      continue;
    }
    final text = _htmlEpubText(body);
    if (text.isEmpty) continue;
    final heading = document
        .querySelectorAll('h1, h2, h3, h4, h5, h6')
        .map(_htmlEpubText)
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    chapterTexts.add(text);
    titles.add(heading.isEmpty ? null : heading);
  }

  if (skippedChapters > 0) {
    debugPrint(
      'Skipped $skippedChapters EPUB chapter(s) that could not be parsed.',
    );
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

String _stripBom(String s) => s.startsWith('\uFEFF') ? s.substring(1) : s;

String? _resolveEpubHref(String basePath, String href) {
  final String path;
  try {
    path = Uri.decodeComponent(Uri.parse(href).path);
  } on Object {
    return null;
  }
  return _normalizeEpubPath(p.posix.join(basePath, path));
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

String _htmlEpubText(html.Node node) {
  final output = StringBuffer();
  const blockElements = {
    'address',
    'article',
    'blockquote',
    'dd',
    'div',
    'dt',
    'figcaption',
    'figure',
    'footer',
    'header',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'li',
    'ol',
    'p',
    'pre',
    'section',
    'aside',
    'table',
    'td',
    'th',
    'tr',
    'ul',
  };

  void visit(html.Node current) {
    if (current is html.Text) {
      output.write(current.data);
    } else if (current is html.Element) {
      final name = current.localName?.toLowerCase();
      if (name == 'script' || name == 'style' || name == 'nav') return;
      final isBlock = blockElements.contains(name);
      if (isBlock) output.write('\n\n');
      if (name == 'br') {
        output.write('\n');
      } else {
        for (final child in current.nodes) {
          visit(child);
        }
      }
      if (isBlock) output.write('\n\n');
    } else {
      for (final child in current.nodes) {
        visit(child);
      }
    }
  }

  visit(node);
  return output
      .toString()
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .join('\n\n');
}
