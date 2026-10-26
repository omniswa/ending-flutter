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
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Favorites', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(all == 1 ? '1 book saved' : '$all books saved', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Filter>(
                showSelectedIcon: false,
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
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _Sort.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _Sort.values[i];
                final sel = s == _sort;
                return ChoiceChip(
                  selected: sel,
                  showCheckmark: false,
                  avatar: Icon(s.icon, size: 16, color: sel ? Colors.white : AppColors.muted),
                  label: Text(s.label, style: TextStyle(color: sel ? Colors.white : AppColors.ink)),
                  onSelected: (_) => setState(() => _sort = s),
                );
              },
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: all == 0 ? 'No favorites yet' : 'Nothing here',
                    message: all == 0
                        ? 'Tap the heart on any book to save it here.'
                        : 'No books match this filter.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _FavoriteCard(item: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserDataProvider>();
    final t = Theme.of(context).textTheme;
    final book = item.book;
    final finished = item.entry.finished;
    final p = item.progress;

    return Dismissible(
      key: ValueKey('fav_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        final removed = user.removeFavorite(book.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('Removed "${book.title}"'),
            action: removed == null ? null : SnackBarAction(label: 'UNDO', onPressed: () => user.restoreFavorite(removed)),
          ));
      },
      child: SoftCard(
        onTap: () => ReaderScreen.open(context, book),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: book.cover, width: 76, height: 114),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 114,
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
                              Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (v) {
                              if (v == 'finish') user.setFinished(book.id, finished: !finished);
                              if (v == 'remove') user.removeFavorite(book.id);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'finish',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(finished ? Icons.undo_rounded : Icons.check_circle_outline_rounded),
                                  title: Text(finished ? 'Mark as reading' : 'Mark as finished'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.favorite_border_rounded, color: AppColors.danger),
                                  title: Text('Remove from favorites'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (finished)
                      const _Badge(icon: Icons.check_circle_rounded, label: 'Finished', color: AppColors.sage)
                    else if (p != null) ...[
                      Text('${formatPercent(p.percent)} · ${formatTimeLeft(p.minutesLeft)}', style: t.labelSmall?.copyWith(color: AppColors.muted)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: p.percent.clamp(0.02, 1.0), minHeight: 5, backgroundColor: AppColors.chip, color: AppColors.terracotta),
                      ),
                    ] else
                      const _Badge(icon: Icons.bookmark_border_rounded, label: 'Not started', color: AppColors.muted),
                    Text('Saved ${formatDate(item.entry.addedAt)}', style: t.labelSmall?.copyWith(color: AppColors.muted)),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]);
}
