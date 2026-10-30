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
  final List<String?> titles;
}

class BookRepository {
  BookRepository(this._store, {http.Client? client})
    : _client = client ?? http.Client();

  static const _cacheKey = 'books_index_cache';
  static const _epubExtractionVersion = '2';
  static const _epubExtractionVersionFile = '.epub-extraction-version';
  final LocalStore _store;
  final http.Client _client;

  void dispose() => _client.close();

  Uri _resolve(String path) => Uri.parse(AppConfig.baseUrl).resolve(path);

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

  Future<BookContent> loadContent(Book book, {bool refresh = false}) {
    final running = _inFlight[book.id];
    if (running != null) return running;
    final future = _loadContent(book, refresh: refresh).whenComplete(() {
      _inFlight.remove(book.id);
    });
    return _inFlight[book.id] = future;
  }

  Future<bool> isDownloaded(Book book) async =>
      _hasContent(await _bookDir(book));

  Future<void> deleteDownload(Book book) async {
    await _inFlight[book.id]?.catchError((_) => const BookContent([], []));
    final dir = await _bookDir(book);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<BookContent> _loadContent(Book book, {required bool refresh}) async {
    final dir = await _bookDir(book);
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
      if (dir.existsSync()) await dir.delete(recursive: true);
      await tmp.rename(dir.path);
    } on Object {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
      rethrow;
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
  const frontMatterTypes = {
    'cover',
    'title-page',
    'copyright-page',
    'toc',
    'dedication',
    'acknowledgments',
    'acknowledgements',
    'uncopyright',
    'endnotes',
    'colophon',
    'foreword',
    'preface',
  };
  final frontMatterPaths = <String>{};
  final frontMatterReferences = [
    ...packageXml.findAllElements('reference', namespaceUri: '*'),
    ...packageXml.findAllElements('a', namespaceUri: '*'),
  ];
  for (final reference in frontMatterReferences) {
    final types = [
      reference.getAttribute('type') ?? '',
      reference.getAttribute(
            'type',
            namespaceUri: 'http://www.idpf.org/2007/ops',
          ) ??
          '',
    ].join(' ').toLowerCase().split(RegExp(r'\s+'));
    final href = reference.getAttribute('href');
    if (href == null || !types.any(frontMatterTypes.contains)) continue;
    final path = _normalizeEpubPath(
      p.posix.join(basePath, Uri.parse(href).path),
    );
    if (path != null) frontMatterPaths.add(path);
  }

  final chapterTexts = <String>[];
  final titles = <String?>[];
  var startedMainContent = false;
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
    final path = _normalizeEpubPath(
      p.posix.join(basePath, Uri.parse(item.href).path),
    );
    if (path == null) continue;
    final chapter = files[path];
    if (chapter == null) continue;

    final document = XmlDocument.parse(
      utf8.decode(chapter, allowMalformed: true),
      entityMapping: const XmlDefaultEntityMapping.html5(),
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
    final documentTitle = document
        .findAllElements('title', namespaceUri: '*')
        .map((element) => _epubText(element))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final isFrontMatter =
        frontMatterPaths.contains(path) ||
        (!startedMainContent &&
            _isEpubFrontMatter(path, heading, documentTitle, text));
    if (isFrontMatter) continue;
    startedMainContent = true;
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

bool _isEpubFrontMatter(
  String path,
  String heading,
  String documentTitle,
  String text,
) {
  final normalizedPath = path.toLowerCase();
  final filenameIndicatesFrontMatter = RegExp(
    r'(^|[/_.\-\s])(cover|coverpage|title|title[-_ ]?page|copyright(?:[-_ ]?page)?|colophon|dedication|frontispiece|contents|table[-_ ]of[-_ ]contents|toc)([/_.\-\s]|$)',
  ).hasMatch(normalizedPath);
  if (filenameIndicatesFrontMatter) return true;

  bool isFrontMatterTitle(String title) => RegExp(
    r'^(cover(?: page)?|title(?: page)?|copyright(?: page)?|colophon|dedication|frontispiece|contents|table of contents|acknowledg(?:e)?ments)$',
    caseSensitive: false,
  ).hasMatch(title.trim());
  if (isFrontMatterTitle(heading) || isFrontMatterTitle(documentTitle)) {
    return true;
  }

  return RegExp(
    r'\b(copyright|all rights reserved|isbn|cataloging-in-publication)\b',
    caseSensitive: false,
  ).hasMatch(text.length > 1200 ? text.substring(0, 1200) : text);
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
