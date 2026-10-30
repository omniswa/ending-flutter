import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../widgets/common.dart';
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
  final Map<int, BuildContext> _paragraphContexts = {};

  List<String>? _chapters;
  List<String?> _titles = const [];
  List<int> _paragraphOffsets = const [];
  ({int paragraph, double offset})? _location;
  Object? _error;
  int _chapter = 0;
  bool _chrome = true;
  bool _showHint = false;
  Timer? _saveTimer;
  Timer? _hintTimer;
  ReaderPrefs? _lastPrefs;
  bool _restoring = false;
  int _relayoutGeneration = 0;
  int _restoreGeneration = 0;

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
    _user.flush();
    _scroll.dispose();
    _fraction.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persist();
      _user.flush();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) _persist();
    _restoreGeneration++;
    _relayoutGeneration++;
    _restoring = false;
    _paragraphContexts.clear();
    setState(() {
      _error = null;
      _chapters = null;
    });
    try {
      final content = await _repo.loadContent(widget.book, refresh: refresh);
      final chapters = content.chapters;
      if (!mounted) return;
      if (content.refreshFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not re-download "${widget.book.title}". Using saved copy.',
            ),
          ),
        );
      }
      final saved = _user.progressFor(widget.book.id);
      final chapter = (saved?.chapter ?? 0)
          .clamp(0, chapters.length - 1)
          .toInt();
      setState(() {
        _chapters = chapters;
        _titles = content.titles;
        _chapter = chapter;
      });
      final paragraphs = _paragraphsFor(chapters[chapter]);
      _location = _savedLocation(saved, paragraphs);
      _fraction.value = _chapterFraction(_location, paragraphs);
      _restoreLocation(_location);
      _persist();
      _maybeShowHint();
    } on Object catch (e, st) {
      debugPrint('Book load failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  ({int paragraph, double offset})? _savedLocation(
    ReadingProgress? saved,
    List<String> paragraphs,
  ) {
    if (paragraphs.isEmpty) return null;
    final paragraph = saved?.paragraph;
    final offset = saved?.paragraphOffset;
    if (paragraph != null && offset != null) {
      return (
        paragraph: paragraph.clamp(0, paragraphs.length - 1).toInt(),
        offset: offset.clamp(0.0, 1.0).toDouble(),
      );
    }

    final target =
        (saved?.scroll ?? 0).clamp(0.0, 1.0) *
        paragraphs.fold<int>(0, (total, text) => total + text.length);
    var before = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      final end = before + paragraphs[i].length;
      if (target <= end || i == paragraphs.length - 1) {
        return (
          paragraph: i,
          offset: paragraphs[i].isEmpty
              ? 0
              : ((target - before) / paragraphs[i].length)
                    .clamp(0.0, 1.0)
                    .toDouble(),
        );
      }
      before = end;
    }
    return (paragraph: 0, offset: 0);
  }

  double _chapterFraction(
    ({int paragraph, double offset})? location,
    List<String> paragraphs,
  ) {
    if (location == null ||
        paragraphs.isEmpty ||
        location.paragraph < 0 ||
        location.paragraph >= paragraphs.length) {
      return 0;
    }
    final before = _paragraphOffsets[location.paragraph];
    final total = _paragraphOffsets.last;
    if (total == 0) return 0;
    final currentLength = paragraphs[location.paragraph].length;
    return ((before + currentLength * location.offset) / total)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _viewportTop() {
    if (!_scroll.hasClients) return 0;
    final renderObject = _scroll.position.context.notificationContext
        ?.findRenderObject();
    return renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero).dy
        : 0;
  }

  double _readingTop(double viewportTop) {
    if (!_chrome) return viewportTop;
    return viewportTop + MediaQuery.of(context).padding.top + 76;
  }

  ({
    ({int paragraph, double offset}) location,
    RenderParagraph box,
    double viewportTop,
  })?
  _visibleParagraph() {
    final chapters = _chapters;
    if (!_scroll.hasClients || chapters == null) return null;
    final viewportTop = _readingTop(_viewportTop());
    var top = double.infinity;
    ({int paragraph, double offset})? location;
    RenderParagraph? visibleBox;
    for (final entry in _paragraphContexts.entries) {
      final renderObject = entry.value.findRenderObject();
      if (renderObject is! RenderParagraph || !renderObject.hasSize) continue;
      final paragraphTop = renderObject.localToGlobal(Offset.zero).dy;
      final paragraphBottom = paragraphTop + renderObject.size.height;
      if (paragraphBottom <= viewportTop || paragraphTop >= top) continue;
      top = paragraphTop;
      visibleBox = renderObject;
      final localY = (viewportTop - paragraphTop)
          .clamp(0.0, renderObject.size.height)
          .toDouble();
      final textOffset = renderObject
          .getPositionForOffset(Offset(0, localY))
          .offset;
      final textLength = _paragraphsFor(chapters[_chapter])[entry.key].length;
      location = (
        paragraph: entry.key,
        offset: textLength == 0
            ? 0
            : (textOffset / textLength).clamp(0.0, 1.0).toDouble(),
      );
    }
    if (location != null && visibleBox != null) {
      return (location: location, box: visibleBox, viewportTop: viewportTop);
    }
    final paragraphs = _paragraphsFor(chapters[_chapter]);
    if (paragraphs.isNotEmpty) {
      final index = paragraphs.length - 1;
      final renderObject = _paragraphContexts[index]?.findRenderObject();
      if (renderObject is RenderParagraph && renderObject.hasSize) {
        final lastBottom =
            renderObject.localToGlobal(Offset.zero).dy +
            renderObject.size.height;
        if (lastBottom <= viewportTop ||
            _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1) {
          return (
            location: (paragraph: index, offset: 1),
            box: renderObject,
            viewportTop: viewportTop,
          );
        }
      }
    }
    return null;
  }

  void _restoreLocation(
    ({int paragraph, double offset})? target, {
    int passes = 16,
  }) {
    if (target == null) return;
    _restoring = true;
    final generation = ++_restoreGeneration;
    final paragraphs = _paragraphsFor(_chapters![_chapter]);
    final targetFraction = _chapterFraction(target, paragraphs);

    void restorePass(int remaining, {bool estimate = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != _restoreGeneration) return;
        if (!mounted || !_scroll.hasClients) {
          _restoring = false;
          return;
        }
        final position = _scroll.position;
        final max = position.maxScrollExtent;
        if (estimate && max > 0) {
          position.jumpTo((max * targetFraction).clamp(0.0, max));
        }

        final visible = _visibleParagraph();
        if (visible?.location.paragraph == target.paragraph) {
          final targetContext = _paragraphContexts[target.paragraph];
          final targetBox = targetContext?.findRenderObject();
          final atChapterStart =
              target.paragraph == 0 &&
              target.offset == 0 &&
              targetFraction == 0;
          if (!atChapterStart &&
              targetBox is RenderParagraph &&
              targetBox.hasSize) {
            final textOffset =
                (paragraphs[target.paragraph].length * target.offset)
                    .round()
                    .clamp(0, paragraphs[target.paragraph].length);
            final caretOffset = targetBox.getOffsetForCaret(
              TextPosition(offset: textOffset),
              Rect.zero,
            );
            final pointY = targetBox.localToGlobal(caretOffset).dy;
            final delta = pointY - visible!.viewportTop;
            final next = (position.pixels + delta).clamp(0.0, max);
            if ((next - position.pixels).abs() > 1) position.jumpTo(next);
          }
          _location = target;
          _fraction.value = targetFraction;
          _restoring = false;
          return;
        }
        if (remaining <= 0) {
          _restoring = false;
          if (visible != null) {
            _location = visible.location;
            _fraction.value = _chapterFraction(visible.location, paragraphs);
          }
          return;
        }

        final currentFraction = visible == null
            ? (max > 0 ? position.pixels / max : 0.0)
            : _chapterFraction(visible.location, paragraphs);
        final correction = (targetFraction - currentFraction) * max;
        final next = (position.pixels + correction).clamp(0.0, max);
        if ((next - position.pixels).abs() <= 1) {
          _restoring = false;
          return;
        }
        position.jumpTo(next);
        restorePass(remaining - 1);
      });
    }

    restorePass(passes, estimate: true);
  }

  void _preservePositionOnRelayout() {
    final visible = _visibleParagraph();
    if (visible == null) return;
    _restoreGeneration++;
    final location = visible.location;
    final paragraphs = _paragraphsFor(_chapters![_chapter]);
    final textOffset = (paragraphs[location.paragraph].length * location.offset)
        .round()
        .clamp(0, paragraphs[location.paragraph].length);
    final caretOffset = visible.box.getOffsetForCaret(
      TextPosition(offset: textOffset),
      Rect.zero,
    );
    final targetY = visible.box.localToGlobal(caretOffset).dy;
    final generation = ++_relayoutGeneration;
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scroll.hasClients ||
          generation != _relayoutGeneration) {
        return;
      }
      final renderObject = _paragraphContexts[location.paragraph]
          ?.findRenderObject();
      if (renderObject is RenderParagraph && renderObject.hasSize) {
        final caretOffset = renderObject.getOffsetForCaret(
          TextPosition(offset: textOffset),
          Rect.zero,
        );
        final pointY = renderObject.localToGlobal(caretOffset).dy;
        final position = _scroll.position;
        final next = (position.pixels + pointY - targetY).clamp(
          0.0,
          position.maxScrollExtent,
        );
        if ((next - position.pixels).abs() > 1) position.jumpTo(next);
      }
      _location = location;
      _fraction.value = _chapterFraction(location, paragraphs);
      _restoring = false;
    });
  }

  void _registerParagraph(int index, BuildContext context) {
    _paragraphContexts[index] = context;
  }

  void _unregisterParagraph(int index, BuildContext context) {
    if (identical(_paragraphContexts[index], context)) {
      _paragraphContexts.remove(index);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (_restoring) {
      if (n is! UserScrollNotification || n.direction == ScrollDirection.idle) {
        return false;
      }
      _restoreGeneration++;
      _restoring = false;
    }
    if (_chapters == null) return false;
    final visible = _visibleParagraph();
    if (visible != null) {
      _location = visible.location;
      _fraction.value = _chapterFraction(
        visible.location,
        _paragraphsFor(_chapters![_chapter]),
      );
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _persist);
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
        paragraph: _location?.paragraph,
        paragraphOffset: _location?.offset,
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
    _restoreGeneration++;
    _relayoutGeneration++;
    _restoring = false;
    setState(() => _chapter = i);
    _paragraphContexts.clear();
    _location = (paragraph: 0, offset: 0);
    _fraction.value = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _persist();
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You reached the end.')));
      return;
    }
    final finish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You reached the end'),
        content: const Text('Mark this book as finished?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
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

  Future<void> _removeDownload() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove download?',
      message:
          'The book is deleted from this device. Your progress is kept '
          'and you can download it again anytime.',
      action: 'Remove',
    );
    if (!ok || !mounted) return;
    _persist();
    await _repo.deleteDownload(widget.book);
    if (mounted) Navigator.of(context).maybePop();
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
        _chapters != null) {
      _preservePositionOnRelayout();
    }
    _lastPrefs = prefs;
    final theme = prefs.theme;

    return PopScope(
      onPopInvokedWithResult: (_, _) => _persist(),
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
    final style = _styleFor(prefs);
    final paragraphs = _paragraphsFor(chapters[_chapter]);
    final isLast = _chapter == chapters.length - 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleChrome,
      onHorizontalDragEnd: _onSwipe,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                prefs.margin,
                media.padding.top + 76,
                prefs.margin,
                media.padding.bottom + 100,
              ),
              sliver: SliverList.builder(
                itemCount: paragraphs.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _chapterHeader(theme, style);
                  if (index == paragraphs.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _endFooter(theme, isLast),
                    );
                  }
                  final paragraphIndex = index - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: prefs.fontSize * 0.9),
                    child: _TrackedParagraph(
                      key: ValueKey('$_chapter-$paragraphIndex'),
                      index: paragraphIndex,
                      onMount: _registerParagraph,
                      onUnmount: _unregisterParagraph,
                      child: Text(
                        paragraphs[paragraphIndex],
                        textAlign: prefs.align,
                        style: style,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chapterHeader(ReaderTheme theme, TextStyle style) {
    return Column(
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
          child: Container(width: 32, height: 2, color: AppColors.terracotta),
        ),
        if (_titles[_chapter] != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              _titles[_chapter]!,
              textAlign: TextAlign.center,
              style: googleFontStyleWithWeight(
                style,
                FontWeight.w700,
              )!.copyWith(fontSize: style.fontSize! + 4),
            ),
          ),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  List<String>? _paraCache;
  String? _paraSource;

  List<String> _paragraphsFor(String text) {
    if (_paraCache == null || !identical(_paraSource, text)) {
      _paraSource = text;
      _paraCache = text
          .replaceAll('\r\n', '\n')
          .trim()
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      _paragraphOffsets = List<int>.filled(_paraCache!.length + 1, 0);
      for (var i = 0; i < _paraCache!.length; i++) {
        _paragraphOffsets[i + 1] = _paragraphOffsets[i] + _paraCache![i].length;
      }
    }
    return _paraCache!;
  }

  ReaderPrefs? _styleSource;
  TextStyle? _styleCache;

  TextStyle _styleFor(ReaderPrefs prefs) {
    if (_styleCache == null || !identical(_styleSource, prefs)) {
      _styleSource = prefs;
      _styleCache = prefs.textStyle;
    }
    return _styleCache!;
  }

  Widget _endFooter(ReaderTheme theme, bool isLast) {
    final color = theme.fg.withValues(alpha: 0.5);
    final label = isLast
        ? 'Swipe left to finish'
        : 'Swipe left for next chapter';
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
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
            builder: (_, u, _) {
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
                      fav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: fav ? AppColors.terracotta : theme.fg,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: Icon(Icons.more_vert_rounded, color: theme.fg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (v) {
                      switch (v) {
                        case 'finished':
                          u.setFinished(id, finished: !done);
                        case 'refresh':
                          _load(refresh: true);
                        case 'remove':
                          _removeDownload();
                      }
                    },
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
                            Text(
                              done
                                  ? 'Mark as not finished'
                                  : 'Mark as finished',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Re-download book'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 12),
                            Text('Remove download'),
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
                      builder: (_, _, _) {
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
            final text = chapters[i];
            final head = text.length > 240 ? text.substring(0, 240) : text;
            final preview = head.trim().replaceAll(RegExp(r'\s+'), ' ');
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

class _TrackedParagraph extends StatefulWidget {
  const _TrackedParagraph({
    super.key,
    required this.index,
    required this.onMount,
    required this.onUnmount,
    required this.child,
  });

  final int index;
  final void Function(int, BuildContext) onMount;
  final void Function(int, BuildContext) onUnmount;
  final Widget child;

  @override
  State<_TrackedParagraph> createState() => _TrackedParagraphState();
}

class _TrackedParagraphState extends State<_TrackedParagraph> {
  @override
  void initState() {
    super.initState();
    widget.onMount(widget.index, context);
  }

  @override
  void didUpdateWidget(covariant _TrackedParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      oldWidget.onUnmount(oldWidget.index, context);
      widget.onMount(widget.index, context);
    }
  }

  @override
  void dispose() {
    widget.onUnmount(widget.index, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
