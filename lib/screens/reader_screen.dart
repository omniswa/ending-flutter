import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  late final ReaderSettingsProvider _settings;
  final _scroll = ScrollController();
  final _fraction = ValueNotifier<double>(0);

  List<String>? _chapters;
  List<String?> _titles = const [];
  Object? _error;
  int _chapter = 0;
  bool _chrome = true;
  bool _showHint = false;
  Timer? _saveTimer;
  Timer? _hintTimer;
  ReaderPrefs? _lastPrefs;

  /// Minimum horizontal fling speed (logical px/s) that counts as a swipe.
  static const _swipeVelocity = 300.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = context.read<BookRepository>();
    _user = context.read<UserDataProvider>();
    _settings = context.read<ReaderSettingsProvider>();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _hintTimer?.cancel();
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
      _maybeShowHint();
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
    final chapters = _chapters;
    if (chapters == null || i < 0 || i >= chapters.length || i == _chapter) {
      return;
    }
    HapticFeedback.selectionClick();
    _dismissHint();
    setState(() => _chapter = i);
    _fraction.value = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _persist();
  }

  /// One-time hint explaining swipe navigation; shown on the first book opened.
  void _maybeShowHint() {
    if (_settings.hintSeen) return;
    _settings.markHintSeen();
    setState(() => _showHint = true);
    _hintTimer = Timer(const Duration(seconds: 6), _dismissHint);
  }

  void _dismissHint() {
    _hintTimer?.cancel();
    if (_showHint && mounted) setState(() => _showHint = false);
  }

  void _onSwipe(DragEndDetails d) {
    final chapters = _chapters;
    final v = d.primaryVelocity ?? 0;
    if (chapters == null || v.abs() < _swipeVelocity) return;
    if (v < 0) {
      _next();
    } else {
      _goTo(_chapter - 1);
    }
  }

  /// Next chapter, or the finish prompt when already on the last one.
  void _next() {
    final chapters = _chapters;
    if (chapters == null) return;
    if (_chapter < chapters.length - 1) {
      _goTo(_chapter + 1);
    } else {
      _promptFinish();
    }
  }

  Future<void> _promptFinish() async {
    _dismissHint();
    if (_user.isFinished(widget.book.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'ve reached the end of this book.')),
      );
      return;
    }
    final finish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You\'ve reached the end'),
        content: const Text('Mark this book as finished?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish book'),
          ),
        ],
      ),
    );
    if (finish != true || !mounted) return;
    _user.setFinished(widget.book.id, finished: true);
    Navigator.of(context).maybePop();
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
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
              _hint(theme),
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
      onHorizontalDragEnd: _onSwipe,
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
              const SizedBox(height: 16),
              _endFooter(theme, isLast),
            ],
          ),
        ),
      ),
    );
  }

  /// Quiet end-of-chapter cue in place of the old Previous/Next buttons.
  /// Tapping it works too, for anyone who can't swipe.
  Widget _endFooter(ReaderTheme theme, bool isLast) {
    final color = theme.fg.withValues(alpha: 0.5);
    final label = isLast ? 'Swipe left to finish' : 'Swipe left for next chapter';
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _next,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 13)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(ReaderTheme theme) {
    final bottom = MediaQuery.of(context).padding.bottom + 84;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: IgnorePointer(
        ignoring: !_showHint,
        child: AnimatedOpacity(
          opacity: _showHint ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: GestureDetector(
            onTap: _dismissHint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swipe_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Swipe left or right to change chapters. Tap the page to show or hide controls.',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
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
              final id = widget.book.id;
              final fav = u.isFavorite(id);
              final done = u.isFinished(id);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: () => u.toggleFavorite(id),
                    icon: Icon(
                      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: fav ? AppColors.terracotta : theme.fg,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: Icon(Icons.more_vert_rounded, color: theme.fg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (_) => u.setFinished(id, finished: !done),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'finished',
                        child: Row(
                          children: [
                            Icon(
                              done
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(done ? 'Mark as not finished' : 'Mark as finished'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
