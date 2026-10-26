import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../providers/library_provider.dart';
import '../providers/user_data_provider.dart';
import '../widgets/common.dart';
import '../widgets/recent_card.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch(LibraryProvider lib) {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _search.clear();
      lib.setQuery('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final user = context.watch<UserDataProvider>();
    final t = Theme.of(context).textTheme;

    final recent = <(Book, ReadingProgress)>[];
    for (final p in user.recent) {
      final b = lib.byId(p.bookId);
      if (b != null) recent.add((b, p));
    }
    final books = lib.filtered;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: lib.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(lib)),
            if (_searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: lib.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search by title or author',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
            if (recent.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle(
                  'Recently Read',
                  trailing: recent.length > 4
                      ? TextButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecentScreen(items: recent))),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('SEE ALL', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.terracotta),
                        )
                      : null,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate: recentGridDelegate,
                  itemCount: math.min(4, recent.length),
                  itemBuilder: (_, i) => RecentCard(
                    book: recent[i].$1,
                    progress: recent[i].$2,
                    onTap: () => ReaderScreen.open(context, recent[i].$1),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionTitle('Library', trailing: Text('${books.length} books', style: t.labelMedium?.copyWith(color: AppColors.muted))),
            ),
            if (lib.author != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(label: Text(lib.author!), onDeleted: () => lib.setAuthor(null)),
                  ),
                ),
              ),
            ..._librarySlivers(lib, user, books),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  Widget _header(LibraryProvider lib) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_stories_rounded, color: AppColors.terracotta, size: 34),
                    const SizedBox(width: 8),
                    Text(AppConfig.appName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 4),
                  Text(AppConfig.tagline,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2.2, color: AppColors.muted)),
                ],
              ),
            ),
            RoundIconButton(icon: _searching ? Icons.close_rounded : Icons.search_rounded, tooltip: 'Search', onTap: () => _toggleSearch(lib)),
            const SizedBox(width: 10),
            RoundIconButton(icon: Icons.tune_rounded, tooltip: 'Filter by author', badge: lib.author != null, onTap: () => _showFilterSheet(context)),
          ],
        ),
      );

  List<Widget> _librarySlivers(LibraryProvider lib, UserDataProvider user, List<Book> books) {
    switch (lib.state) {
      case LoadState.loading:
        return const [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())))];
      case LoadState.error:
        return [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load your library',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: lib.load,
            ),
          ),
        ];
      case LoadState.ready:
        if (books.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No books found',
                message: 'Try a different title, author, or clear your filters.',
                actionLabel: lib.hasFilters ? 'Clear filters' : null,
                onAction: () {
                  _search.clear();
                  lib.clearFilters();
                },
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _LibraryCard(
                book: books[i],
                progress: user.progressFor(books[i].id),
                favorite: user.isFavorite(books[i].id),
                onFavorite: () => user.toggleFavorite(books[i].id),
              ),
            ),
          ),
        ];
    }
  }

  void _showFilterSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _FilterSheet(),
      );
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.book, required this.progress, required this.favorite, required this.onFavorite});
  final Book book;
  final ReadingProgress? progress;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final started = progress != null && progress!.percent > 0;
    return SoftCard(
      onTap: () => ReaderScreen.open(context, book),
      child: SizedBox(
        height: 132,
        child: Row(
          children: [
            BookCover(url: book.cover, width: 88, height: 132),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
                            const SizedBox(height: 2),
                            Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
                            Text('Added: ${formatDate(book.added)}', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                        style: IconButton.styleFrom(backgroundColor: AppColors.chip),
                        onPressed: onFavorite,
                        icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20, color: favorite ? AppColors.terracotta : AppColors.ink),
                      ),
                    ],
                  ),
                  PillButton(
                    label: started ? 'Continue · ${formatPercent(progress!.percent)}' : 'Read Book',
                    onPressed: () => ReaderScreen.open(context, book),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Filter by author', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: lib.author == null ? null : () => lib.setAuthor(null), child: const Text('Clear')),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in lib.authors)
                      ChoiceChip(
                        label: Text(a),
                        selected: lib.author == a,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: lib.author == a ? Colors.white : AppColors.ink),
                        onSelected: (sel) {
                          lib.setAuthor(sel ? a : null);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key, required this.items});
  final List<(Book, ReadingProgress)> items;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recently Read')),
        body: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: recentGridDelegate,
          itemCount: items.length,
          itemBuilder: (_, i) => RecentCard(
            book: items[i].$1,
            progress: items[i].$2,
            onTap: () => ReaderScreen.open(context, items[i].$1),
          ),
        ),
      );
}
