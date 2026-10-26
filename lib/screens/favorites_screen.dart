import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/favorite_entry.dart';
import '../models/reading_progress.dart';
import '../providers/library_provider.dart';
import '../providers/user_data_provider.dart';
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
    final items = <_Item>[
      for (final f in user.favorites)
        if (lib.byId(f.bookId) case final b?) _Item(b, f, user.progressFor(b.id)),
    ].where((i) => switch (_filter) {
          _Filter.all => true,
          _Filter.reading => !i.entry.finished,
          _Filter.finished => i.entry.finished,
        }).toList();

    int cmp(_Item a, _Item b) => switch (_sort) {
          _Sort.added => b.entry.addedAt.compareTo(a.entry.addedAt),
          _Sort.title => a.book.title.toLowerCase().compareTo(b.book.title.toLowerCase()),
          _Sort.author => a.book.author.toLowerCase().compareTo(b.book.author.toLowerCase()),
          _Sort.lastRead => (b.progress?.lastOpened ?? _epoch).compareTo(a.progress?.lastOpened ?? _epoch),
        };
    return items..sort(cmp);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final user = context.watch<UserDataProvider>();
    final t = Theme.of(context).textTheme;
    final all = user.favorites.length;
    final items = _items(lib, user);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Favorites', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(all == 1 ? '1 book saved' : '$all books saved', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  ]),
                ),
                PopupMenuButton<_Sort>(
                  tooltip: 'Sort by',
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    for (final s in _Sort.values)
                      PopupMenuItem(
                        value: s,
                        child: Row(children: [
                          Icon(s.icon, size: 18, color: s == _sort ? AppColors.sage : AppColors.muted),
                          const SizedBox(width: 12),
                          Text(s.label, style: TextStyle(fontWeight: s == _sort ? FontWeight.w700 : FontWeight.w500)),
                        ]),
                      ),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
                    child: const Icon(Icons.sort_rounded, size: 22),
                  ),
                ),
              ],
            ),
          ),
          if (all > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.chip,
                    selectedBackgroundColor: AppColors.sage,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    side: BorderSide.none,
                  ),
                  segments: const [
                    ButtonSegment(value: _Filter.all, label: Text('All')),
                    ButtonSegment(value: _Filter.reading, label: Text('Reading')),
                    ButtonSegment(value: _Filter.finished, label: Text('Finished')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: all == 0 ? 'No favorites yet' : 'Nothing here',
                    message: all == 0 ? 'Tap the heart on any book to save it here.' : 'No books match this filter.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _FavoriteCard(key: ValueKey('fav_${items[i].book.id}'), item: items[i]),
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
    showUndoSnack(context, 'Removed "${book.title}"', () => user.restoreFavorite(removed));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserDataProvider>();
    final t = Theme.of(context).textTheme;
    final book = item.book;
    final finished = item.entry.finished;
    final p = item.progress;

    return Dismissible(
      key: ValueKey('dismiss_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.favorite_border_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _remove(context, user),
      child: SoftCard(
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
                    if (finished)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.sage),
                        const SizedBox(width: 4),
                        Text('Finished', style: t.labelMedium?.copyWith(color: AppColors.sage, fontWeight: FontWeight.w700)),
                      ])
                    else if (p != null && p.percent > 0) ...[
                      ProgressBar(value: p.percent),
                      const SizedBox(height: 5),
                      Text('${formatPercent(p.percent)} · ${formatTimeLeft(p.minutesLeft)}', style: t.labelSmall?.copyWith(color: AppColors.muted)),
                    ] else
                      Text('Not started', style: t.labelSmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    if (v == 'finish') user.setFinished(book.id, finished: !finished);
                    if (v == 'remove') _remove(context, user);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'finish',
                      child: Row(children: [
                        Icon(finished ? Icons.undo_rounded : Icons.check_circle_outline_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(finished ? 'Mark as reading' : 'Mark as finished'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.favorite_border_rounded, size: 20, color: AppColors.danger),
                        SizedBox(width: 12),
                        Text('Remove'),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
