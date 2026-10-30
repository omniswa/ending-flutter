import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/book.dart';
import '../models/favorite_entry.dart';
import '../models/reading_progress.dart';
import '../providers/library_provider.dart';
import '../providers/user_data_provider.dart';
import '../widgets/book_card.dart';
import '../widgets/common.dart';
import 'reader_screen.dart';

enum _Sort {
  added('Date added', Icons.schedule_rounded),
  title('Title', Icons.sort_by_alpha_rounded),
  author('Author', Icons.person_outline_rounded),
  lastRead('Last read', Icons.auto_stories_rounded);

  const _Sort(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum _Filter { all, reading, finished }

class _Item {
  const _Item(this.book, this.entry, this.progress);
  final Book book;
  final FavoriteEntry entry;
  final ReadingProgress? progress;
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  _Sort _sort = _Sort.added;
  _Filter _filter = _Filter.all;

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  List<_Item> _items(LibraryProvider lib, UserDataProvider user) {
    final items =
        <_Item>[
              for (final f in user.favorites)
                if (lib.byId(f.bookId) case final b?)
                  _Item(b, f, user.progressFor(b.id)),
            ]
            .where(
              (i) => switch (_filter) {
                _Filter.all => true,
                _Filter.reading => !user.isFinished(i.book.id),
                _Filter.finished => user.isFinished(i.book.id),
              },
            )
            .toList();

    int cmp(_Item a, _Item b) => switch (_sort) {
      _Sort.added => b.entry.addedAt.compareTo(a.entry.addedAt),
      _Sort.title => a.book.title.toLowerCase().compareTo(
        b.book.title.toLowerCase(),
      ),
      _Sort.author => a.book.author.toLowerCase().compareTo(
        b.book.author.toLowerCase(),
      ),
      _Sort.lastRead => (b.progress?.lastOpened ?? _epoch).compareTo(
        a.progress?.lastOpened ?? _epoch,
      ),
    };
    return items..sort(cmp);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final user = context.watch<UserDataProvider>();
    final libReady = lib.state == LoadState.ready;
    final all = libReady
        ? user.favorites.where((f) => lib.byId(f.bookId) != null).length
        : user.favorites.length;
    final items = _items(lib, user);

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Favorites',
            subtitle: all == 1 ? '1 book saved' : '$all books saved',
            trailing: PopupMenuButton<_Sort>(
              tooltip: 'Sort by',
              initialValue: _sort,
              onSelected: (s) => setState(() => _sort = s),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              itemBuilder: (_) => [
                for (final s in _Sort.values)
                  PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(
                          s.icon,
                          size: 18,
                          color: s == _sort ? AppColors.sage : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontWeight: s == _sort
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sort_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
            bottom: all > 0
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_Filter>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            selectedBackgroundColor: AppColors.sage,
                            selectedForegroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            side: BorderSide.none,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: _Filter.all,
                              label: Text('All'),
                            ),
                            ButtonSegment(
                              value: _Filter.reading,
                              label: Text('Reading'),
                            ),
                            ButtonSegment(
                              value: _Filter.finished,
                              label: Text('Finished'),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (s) =>
                              setState(() => _filter = s.first),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: all == 0 ? 'No favorites yet' : 'Nothing here',
                    message: all == 0
                        ? 'Tap the heart on any book to save it here.'
                        : !libReady
                        ? 'Your library isn\'t loaded yet. Pull to refresh on '
                              'the Home tab.'
                        : 'No books match this filter.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    gridDelegate: BookCard.gridDelegate,
                    itemCount: items.length,
                    itemBuilder: (_, i) => _FavoriteCard(
                      key: ValueKey('fav_${items[i].book.id}'),
                      item: items[i],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({super.key, required this.item});
  final _Item item;

  void _remove(BuildContext context, UserDataProvider user) {
    final book = item.book;
    final removed = user.removeFavorite(book.id);
    if (removed == null) return;
    showUndoSnack(
      context,
      'Removed "${book.title}"',
      () => user.restoreFavorite(removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserDataProvider>();
    final book = item.book;
    final finished = user.isFinished(book.id);

    return BookCard(
      book: book,
      progress: item.progress,
      finished: finished,
      onTap: () async {
        await ReaderScreen.open(context, book);
        if (!context.mounted) return;
        try {
          await context.read<LibraryProvider>().refreshDownloadStatus(book);
        } on Object catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not check offline status: $error')),
            );
          }
        }
      },
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: AppColors.muted,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          fixedSize: const Size(32, 32),
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) {
          if (v == 'finish') user.setFinished(book.id, finished: !finished);
          if (v == 'remove') _remove(context, user);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'finish',
            child: Row(
              children: [
                Icon(
                  finished
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(finished ? 'Mark as reading' : 'Mark as finished'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
                SizedBox(width: 12),
                Text('Remove'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
