import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch(LibraryProvider lib) {
    _search.clear();
    lib.setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final user = context.watch<UserDataProvider>();
    final searching = lib.query.isNotEmpty;

    final recent = <(Book, ReadingProgress)>[];
    if (!searching) {
      for (final p in user.recent) {
        final b = lib.byId(p.bookId);
        if (b != null && p.percent > 0) recent.add((b, p));
        if (recent.length == 8) break;
      }
    }
    final books = lib.filtered;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.sage,
        onRefresh: lib.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _header(context, lib)),
            if (recent.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionTitle('Continue reading')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 252,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => RecentCard(
                      book: recent[i].$1,
                      progress: recent[i].$2,
                      onTap: () => ReaderScreen.open(context, recent[i].$1),
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionTitle(
                searching ? 'Results' : 'Library',
                trailing: lib.state == LoadState.ready
                    ? Text(books.length == 1 ? '1 book' : '${books.length} books',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.muted))
                    : null,
              ),
            ),
            ..._librarySlivers(lib, user, books),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, LibraryProvider lib) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppConfig.appName, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: lib.setQuery,
            decoration: InputDecoration(
              hintText: 'Search titles or authors',
              hintStyle: const TextStyle(color: AppColors.muted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _search,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => _clearSearch(lib),
                      ),
              ),
              filled: true,
              fillColor: AppColors.chip,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _librarySlivers(LibraryProvider lib, UserDataProvider user, List<Book> books) {
    switch (lib.state) {
      case LoadState.loading:
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const _SkeletonCard(),
            ),
          ),
        ];
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
                title: lib.query.isEmpty ? 'No books yet' : 'No matches',
                message: lib.query.isEmpty
                    ? 'Pull down to refresh the library.'
                    : 'Try a different title or author.',
                actionLabel: lib.query.isEmpty ? null : 'Clear search',
                onAction: () => _clearSearch(lib),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _LibraryCard(
                key: ValueKey(books[i].id),
                book: books[i],
                progress: user.progressFor(books[i].id),
                favorite: user.isFavorite(books[i].id),
                onFavorite: () {
                  HapticFeedback.selectionClick();
                  user.toggleFavorite(books[i].id);
                },
              ),
            ),
          ),
        ];
    }
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({super.key, required this.book, required this.progress, required this.favorite, required this.onFavorite});
  final Book book;
  final ReadingProgress? progress;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progress;
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: () => ReaderScreen.open(context, book),
      child: SizedBox(
        height: 108,
        child: Row(
          children: [
            BookCover(url: book.cover, width: 72, height: 108),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  const Spacer(),
                  if (p != null && p.percent > 0) ...[
                    ProgressBar(value: p.percent),
                    const SizedBox(height: 5),
                    Text('${formatPercent(p.percent)} · ${formatTimeLeft(p.minutesLeft)}', style: t.labelSmall?.copyWith(color: AppColors.muted)),
                  ] else
                    Text('Added ${formatDate(book.added)}', style: t.labelSmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IconButton(
                tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: onFavorite,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(favorite),
                    color: favorite ? AppColors.terracotta : AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown while the catalog loads, so the layout doesn't jump.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(4)),
        );
    return SoftCard(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height: 108,
        child: Row(
          children: [
            Container(
              width: 72,
              height: 108,
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  bar(160, 14),
                  const SizedBox(height: 10),
                  bar(100, 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
