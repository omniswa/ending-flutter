import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../providers/library_provider.dart';
import '../providers/user_data_provider.dart';
import '../widgets/book_card.dart';
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
        if (b != null && p.percent > 0 && !user.isFinished(b.id)) {
          recent.add((b, p));
        }
        if (recent.length == 8) break;
      }
    }
    final books = lib.filtered;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, lib),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.sage,
              onRefresh: lib.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (recent.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionTitle('CONTINUE READING'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 204,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: recent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) => RecentCard(
                            book: recent[i].$1,
                            progress: recent[i].$2,
                            onTap: () async {
                              await ReaderScreen.open(context, recent[i].$1);
                              if (context.mounted) {
                                await _refreshOfflineStatus(
                                  context,
                                  lib,
                                  recent[i].$1,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: SectionTitle(
                      searching ? 'RESULTS' : 'LIBRARY',
                      trailing: lib.state == LoadState.ready
                          ? Text(
                              books.length == 1
                                  ? '1 book'
                                  : '${books.length} books',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.muted),
                            )
                          : null,
                    ),
                  ),
                  ..._librarySlivers(lib, user, books),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, LibraryProvider lib) {
    return ScreenHeader(
      title: AppConfig.appName,
      subtitle: AppConfig.tagline,
      subtitleFontSize: 12,
      letterSpacing: 1.6,
      bottom: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: lib.setQuery,
          decoration: InputDecoration(
            hintText: 'Search titles or authors',
            hintStyle: const TextStyle(color: AppColors.muted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.muted,
            ),
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
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _librarySlivers(
    LibraryProvider lib,
    UserDataProvider user,
    List<Book> books,
  ) {
    switch (lib.state) {
      case LoadState.loading:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            ),
          ),
        ];
      case LoadState.error:
        return [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load your library',
              message: [
                'Check your connection and try again.',
                if (lib.errorMessage != null) 'Details: ${lib.errorMessage}',
              ].join('\n\n'),
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
            sliver: SliverGrid.builder(
              gridDelegate: BookCard.gridDelegate,
              itemCount: books.length,
              itemBuilder: (_, i) => _LibraryCard(
                key: ValueKey(books[i].id),
                book: books[i],
                progress: user.progressFor(books[i].id),
                finished: user.isFinished(books[i].id),
                favorite: user.isFavorite(books[i].id),
                downloaded: lib.isDownloaded(books[i].id),
                checkingDownload: lib.isCheckingDownload(books[i].id),
                downloading: lib.isDownloading(books[i].id),
                onFavorite: () {
                  HapticFeedback.selectionClick();
                  user.toggleFavorite(books[i].id);
                },
                onDownload: () => _downloadBook(context, lib, books[i]),
              ),
            ),
          ),
        ];
    }
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    super.key,
    required this.book,
    required this.progress,
    required this.finished,
    required this.favorite,
    required this.downloaded,
    required this.checkingDownload,
    required this.downloading,
    required this.onFavorite,
    required this.onDownload,
  });
  final Book book;
  final ReadingProgress? progress;
  final bool finished;
  final bool favorite;
  final bool downloaded;
  final bool checkingDownload;
  final bool downloading;
  final VoidCallback onFavorite;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => BookCard(
    book: book,
    progress: progress,
    finished: finished,
    onTap: () async {
      await ReaderScreen.open(context, book);
      if (context.mounted) {
        await _refreshOfflineStatus(
          context,
          context.read<LibraryProvider>(),
          book,
        );
      }
    },
    trailing: Column(
      children: [
        IconButton(
          tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: onFavorite,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            fixedSize: const Size(32, 32),
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(favorite),
              size: 18,
              color: favorite ? AppColors.terracotta : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _DownloadControl(
          downloaded: downloaded,
          checking: checkingDownload,
          downloading: downloading,
          onPressed: onDownload,
        ),
      ],
    ),
  );
}

class _DownloadControl extends StatelessWidget {
  const _DownloadControl({
    required this.downloaded,
    required this.checking,
    required this.downloading,
    required this.onPressed,
  });

  final bool downloaded;
  final bool checking;
  final bool downloading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (downloaded) {
      return Tooltip(
        message: 'Available offline',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_done_rounded,
            size: 18,
            color: AppColors.sage,
          ),
        ),
      );
    }
    if (checking || downloading) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.sage,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Download for offline reading',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        fixedSize: const Size(32, 32),
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(
        Icons.cloud_download_rounded,
        size: 18,
        color: AppColors.muted,
      ),
    );
  }
}

Future<void> _downloadBook(
  BuildContext context,
  LibraryProvider library,
  Book book,
) async {
  try {
    await library.download(book);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${book.title}" has been downloaded successfully.'),
        ),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download "${book.title}": $error')),
      );
    }
  }
}

Future<void> _refreshOfflineStatus(
  BuildContext context,
  LibraryProvider library,
  Book book,
) async {
  try {
    await library.refreshDownloadStatus(book);
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check offline status: $error')),
      );
    }
  }
}
