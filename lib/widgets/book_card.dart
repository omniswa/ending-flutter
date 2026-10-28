import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

/// Compact grid tile used on Home and Favorites.
///
/// The cover floats on a softly tinted "stage" (the tint is picked from the
/// book id so the grid has gentle variety). Below it sit a serif title, the
/// author and a one-line status/progress footer. [trailing] is overlaid on the
/// top-right corner of the stage (favorite heart, overflow menu, ...).
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.progress,
    required this.onTap,
    this.finished = false,
    this.trailing,
  });

  final Book book;
  final ReadingProgress? progress;
  final VoidCallback onTap;
  final bool finished;
  final Widget? trailing;

  /// Fixed tile height, for use as the grid's `mainAxisExtent`.
  static const height = 250.0;
  static const _stageHeight = 140.0;

  /// Shared grid layout so Home, Favorites and the skeleton line up.
  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 220,
    mainAxisExtent: height,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
  );

  static const _stages = <List<Color>>[
    [Color(0xFFE9EEE0), Color(0xFFCCD8BE)], // sage
    [Color(0xFFF8E8DA), Color(0xFFEBCBB0)], // terracotta
    [Color(0xFFE5EEF1), Color(0xFFC5D8E0)], // sky
    [Color(0xFFF0E7F5), Color(0xFFDAC9E6)], // lilac
    [Color(0xFFFFF3D1), Color(0xFFF3DC9C)], // butter
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progress;
    final started = p != null && p.percent > 0;
    final isNew = !started &&
        !finished &&
        DateTime.now().difference(book.added).inDays.abs() <= 14;
    final stage = _stages[book.id.abs() % _stages.length];

    return SoftCard(
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: _stageHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: stage,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  BookCover(url: book.cover, width: 84, height: 122),
                  if (isNew)
                    const Positioned(left: 8, top: 8, child: _Badge('New')),
                  if (trailing != null)
                    Positioned(top: 6, right: 6, child: trailing!),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fraunces(
                        textStyle: t.titleSmall,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const Spacer(),
                    _footer(t, p, started),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(TextTheme t, ReadingProgress? p, bool started) {
    if (finished) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.sage),
          const SizedBox(width: 5),
          Text(
            'Finished',
            style: t.labelSmall?.copyWith(
              color: AppColors.sage,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    if (started) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressBar(value: p!.percent, minHeight: 5),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatPercent(p.percent),
                  style: const TextStyle(
                    color: AppColors.terracotta,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '  ·  ${formatTimeLeft(p.minutesLeft)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSmall,
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.bookmark_border_rounded, size: 14, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Added ${formatShortDate(book.added)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.sage,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
      );
}
