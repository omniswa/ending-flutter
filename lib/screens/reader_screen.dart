import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reader_prefs.dart';
import '../models/reading_progress.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/user_data_provider.dart';
import '../services/book_repository.dart';
import '../widgets/reader_settings_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});
  final Book book;

  static Future<void> open(BuildContext context, Book book) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(book: book)));

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late final BookRepository _repo;
  late final UserDataProvider _user;
  final _scroll = ScrollController();
  final _fraction = ValueNotifier<double>(0);

  List<String>? _chapters;
  List<String?> _titles = const [];
  Object? _error;
  int _chapter = 0;
  bool _chrome = true;
  Timer? _saveTimer;
  ReaderPrefs? _lastPrefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = context.read<BookRepository>();
    _user = context.read<UserDataProvider>();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _scroll.dispose();
    _fraction.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive)
      _persist();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _chapters = null;
    });
    try {
      final content = await _repo.loadContent(widget.book);
      final chapters = content.chapters;
      if (!mounted) return;
      final saved = _user.progressFor(widget.book.id);
      setState(() {
        _chapters = chapters;
        _titles = content.titles;
        _chapter = (saved?.chapter ?? 0).clamp(0, chapters.length - 1).toInt();
      });
      _fraction.value = saved?.scroll ?? 0;
      _restoreScroll();
      _persist(); // marks the book as recently read
    } on Object catch (e, st) {
      debugPrint('Book load failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  void _restoreScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo((max * _fraction.value).clamp(0, max).toDouble());
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final max = n.metrics.maxScrollExtent;
    if (max > 0) {
      _fraction.value = (n.metrics.pixels / max).clamp(0.0, 1.0).toDouble();
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 1), _persist);
    }
    return false;
  }

  ({double percent, int minutes}) _stats() {
    final ch = _chapters!;
    final total = ch.fold<int>(0, (s, c) => s + c.length);
    if (total == 0) return (percent: 0, minutes: 0);
    var before = 0;
    for (var i = 0; i < _chapter; i++) {
      before += ch[i].length;
    }
    final pos = before + ch[_chapter].length * _fraction.value;
    final words = (total - pos) / AppConfig.charsPerWord;
    return (
      percent: (pos / total).clamp(0.0, 1.0).toDouble(),
      minutes: (words / AppConfig.wordsPerMinute).ceil(),
    );
  }

  void _persist() {
    if (_chapters == null) return;
    _saveTimer?.cancel();
    final s = _stats();
    _user.saveProgress(
      ReadingProgress(
        bookId: widget.book.id,
        chapter: _chapter,
        scroll: _fraction.value,
        percent: s.percent,
        minutesLeft: s.minutes,
        lastOpened: DateTime.now(),
      ),
    );
  }

  void _goTo(int i) {
    if (i < 0 || i >= _chapters!.length) return;
    setState(() => _chapter = i);
    _fraction.value = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _persist();
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _finish() {
    _user.setFinished(widget.book.id, finished: true);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ReaderSettingsProvider>().prefs;
    if (_lastPrefs != null &&
        !identical(_lastPrefs, prefs) &&
        _chapters != null)
      _restoreScroll();
    _lastPrefs = prefs;
    final theme = prefs.theme;

    return PopScope(
      onPopInvokedWithResult: (_, __) => _persist(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: theme.bg,
          body: Stack(
            children: [
              Positioned.fill(child: _body(prefs)),
              _topBar(theme),
              _bottomBar(theme, prefs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ReaderPrefs prefs) {
    final theme = prefs.theme;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: theme.fg),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t open this book',
              style: TextStyle(color: theme.fg, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final chapters = _chapters;
    if (chapters == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.fg),
            const SizedBox(height: 16),
            Text(
              'Preparing your book…',
              style: TextStyle(color: theme.fg.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    final media = MediaQuery.of(context);
    final style = prefs.textStyle;
    final paragraphs = chapters[_chapter]
        .replaceAll('\r\n', '\n')
        .trim()
        .split(RegExp(r'\n\s*\n'));
    final isLast = _chapter == chapters.length - 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleChrome,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            prefs.margin,
            media.padding.top + 76,
            prefs.margin,
            media.padding.bottom + 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'CHAPTER ${_chapter + 1}',
                  style: TextStyle(
                    color: theme.fg.withValues(alpha: 0.55),
                    letterSpacing: 3,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 32,
                  height: 2,
                  color: AppColors.terracotta,
                ),
              ),
              if (_titles[_chapter] != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _titles[_chapter]!,
                    textAlign: TextAlign.center,
                    style: style.copyWith(
                      fontSize: style.fontSize! + 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              for (final p in paragraphs)
                Padding(
                  padding: EdgeInsets.only(bottom: prefs.fontSize * 0.9),
                  child: Text(p.trim(), textAlign: prefs.align, style: style),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_chapter > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goTo(_chapter - 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.fg,
                          side: BorderSide(
                            color: theme.fg.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_chapter > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isLast ? _finish : () => _goTo(_chapter + 1),
                      child: Text(isLast ? 'Finish book' : 'Next chapter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar({
    required bool top,
    required ReaderTheme theme,
    required Widget child,
  }) => Positioned(
    top: top ? 0 : null,
    bottom: top ? null : 0,
    left: 0,
    right: 0,
    child: IgnorePointer(
      ignoring: !_chrome,
      child: AnimatedSlide(
        offset: _chrome ? Offset.zero : Offset(0, top ? -1 : 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.bg,
              border: Border(
                bottom: top
                    ? BorderSide(color: theme.fg.withValues(alpha: 0.1))
                    : BorderSide.none,
                top: top
                    ? BorderSide.none
                    : BorderSide(color: theme.fg.withValues(alpha: 0.1)),
              ),
            ),
            child: SafeArea(top: top, bottom: !top, child: child),
          ),
        ),
      ),
    ),
  );

  Widget _topBar(ReaderTheme theme) => _bar(
    top: true,
    theme: theme,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: theme.fg),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.fg,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Consumer<UserDataProvider>(
            builder: (_, u, __) {
              final fav = u.isFavorite(widget.book.id);
              return IconButton(
                tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => u.toggleFavorite(widget.book.id),
                icon: Icon(
                  fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? AppColors.terracotta : theme.fg,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _bottomBar(ReaderTheme theme, ReaderPrefs prefs) {
    final chapters = _chapters;
    return _bar(
      top: false,
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: chapters == null ? null : () => _showChapters(theme),
              icon: Icon(Icons.list_rounded, color: theme.fg),
              tooltip: 'Chapters',
            ),
            IconButton(
              onPressed: chapters == null || _chapter == 0
                  ? null
                  : () => _goTo(_chapter - 1),
              icon: Icon(
                Icons.chevron_left_rounded,
                color: theme.fg.withValues(alpha: _chapter == 0 ? 0.3 : 1),
              ),
              tooltip: 'Previous chapter',
            ),
            Expanded(
              child: chapters == null
                  ? const SizedBox.shrink()
                  : ValueListenableBuilder<double>(
                      valueListenable: _fraction,
                      builder: (_, __, ___) {
                        final s = _stats();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Chapter ${_chapter + 1} of ${chapters.length} · ${(s.percent * 100).round()}%',
                              style: TextStyle(
                                color: theme.fg.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: s.percent,
                                minHeight: 4,
                                backgroundColor: theme.fg.withValues(
                                  alpha: 0.12,
                                ),
                                color: AppColors.terracotta,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            IconButton(
              onPressed: chapters == null || _chapter >= chapters.length - 1
                  ? null
                  : () => _goTo(_chapter + 1),
              icon: Icon(
                Icons.chevron_right_rounded,
                color: theme.fg.withValues(
                  alpha: chapters != null && _chapter >= chapters.length - 1
                      ? 0.3
                      : 1,
                ),
              ),
              tooltip: 'Next chapter',
            ),
            IconButton(
              onPressed: () => showReaderSettings(context),
              icon: Icon(Icons.text_fields_rounded, color: theme.fg),
              tooltip: 'Reading settings',
            ),
          ],
        ),
      ),
    );
  }

  void _showChapters(ReaderTheme theme) {
    final chapters = _chapters!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: chapters.length,
          itemBuilder: (_, i) {
            final preview = chapters[i].trim().replaceAll(RegExp(r'\s+'), ' ');
            return ListTile(
              selected: i == _chapter,
              selectedColor: AppColors.sage,
              selectedTileColor: AppColors.sage.withValues(alpha: 0.08),
              title: Text(
                _titles[i] ?? 'Chapter ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: i == _chapter
                  ? const Icon(Icons.bookmark_rounded)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _goTo(i);
              },
            );
          },
        ),
      ),
    );
  }
}
