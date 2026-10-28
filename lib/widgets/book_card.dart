import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

/// Compact, full-bleed grid tile used on Home and Favorites.
///
/// The cover fills the whole tile. Everything else is layered on top of it:
/// a "New" badge (top-left), [trailing] (top-right: favorite heart, overflow
/// menu, ...) and, over a dark scrim at the bottom, the title, author and a
/// one-line status/progress footer.
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

  /// Shared grid layout so Home, Favorites and the skeleton line up.
  /// Portrait, book-cover proportions; three columns on a typical phone.
  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 130,
    childAspectRatio: 0.62,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
  );

  static const _onCover = Colors.white;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progress;
    final started = p != null && p.percent > 0;
    final isNew =
        !started &&
        !finished &&
        DateTime.now().difference(book.added).inDays.abs() <= 14;

    return SoftCard(
      padding: EdgeInsets.zero,
      radius: 10,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          fit: StackFit.expand,
          children: [
            BookCover(
              url: book.cover,
              width: c.maxWidth,
              height: c.maxHeight,
              radius: 0,
            ),
            // Scrim keeps the text readable on any cover.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.ink.withValues(alpha: 0.72),
                      AppColors.ink.withValues(alpha: 0.92),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                          textStyle: t.labelLarge,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          height: 1.15,
                          color: _onCover,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(
                          fontSize: 10,
                          color: _onCover.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _footer(t, p, started),
                    ],
                  ),
                ),
              ),
            ),
            if (isNew) const Positioned(left: 6, top: 6, child: _Badge('New')),
            if (trailing != null) Positioned(top: 4, right: 4, child: trailing!),
          ],
        ),
      ),
    );
  }

  Widget _footer(TextTheme t, ReadingProgress? p, bool started) {
    final small = t.labelSmall?.copyWith(fontSize: 10);
    if (finished) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 12, color: _onCover),
          const SizedBox(width: 4),
          Text(
            'Finished',
            style: small?.copyWith(
              color: _onCover,
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
          ProgressBar(
            value: p!.percent,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatPercent(p.percent),
                  style: const TextStyle(
                    color: Color(0xFFF0C9A8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' · ${formatTimeLeft(p.minutesLeft)}',
                  style: TextStyle(color: _onCover.withValues(alpha: 0.75)),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(
          Icons.bookmark_border_rounded,
          size: 12,
          color: _onCover.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Added ${formatShortDate(book.added)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(color: _onCover.withValues(alpha: 0.75)),
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
