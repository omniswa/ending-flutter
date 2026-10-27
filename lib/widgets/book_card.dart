import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

/// The main book row used on Home and Favorites.
///
/// The cover floats on a softly tinted "stage" (the tint is picked from the
/// book id so a list has gentle variety), next to a status chip, a serif
/// title and a progress footer.
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

  static const height = 140.0;
  static const _stageWidth = 104.0;

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
    final isNew = !started && !finished && DateTime.now().difference(book.added).inDays.abs() <= 14;
    final stage = _stages[book.id.abs() % _stages.length];

    final _Status status = finished
        ? const _Status('Finished', Icons.check_circle_rounded, AppColors.sageSoft, AppColors.sage)
        : started
            ? const _Status('Reading', Icons.auto_stories_rounded, AppColors.terracottaSoft, AppColors.terracotta)
            : isNew
                ? const _Status('New', Icons.auto_awesome_rounded, AppColors.sage, Colors.white)
                : const _Status('Not started', Icons.bookmark_border_rounded, AppColors.chip, AppColors.muted);

    return SoftCard(
      padding: EdgeInsets.zero,
      radius: 24,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Container(
              width: _stageWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: stage),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -22,
                    bottom: -22,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  ),
                  Positioned(
                    right: -14,
                    top: -14,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ),
                  BookCover(url: book.cover, width: 72, height: 108),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(status),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fraunces(
                        textStyle: t.titleMedium,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        height: 1.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                      ),
                    ]),
                    const Spacer(),
                    _footer(t, p, started),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(padding: const EdgeInsets.fromLTRB(0, 8, 8, 0), child: trailing),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _footer(TextTheme t, ReadingProgress? p, bool started) {
    if (finished) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const ProgressBar(value: 1, color: AppColors.sage, minHeight: 6),
        const SizedBox(height: 5),
        Text('Completed', style: t.labelSmall?.copyWith(color: AppColors.sage, fontWeight: FontWeight.w700)),
      ]);
    }
    if (started) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ProgressBar(value: p!.percent, minHeight: 6),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: formatPercent(p.percent), style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.w800)),
            TextSpan(text: '  ·  ${formatTimeLeft(p.minutesLeft)}', style: const TextStyle(color: AppColors.muted)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.labelSmall,
        ),
      ]);
    }
    return Row(children: [
      const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.muted),
      const SizedBox(width: 5),
      Expanded(
        child: Text('Added ${formatDate(book.added)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: AppColors.muted)),
      ),
    ]);
  }
}

class _Status {
  const _Status(this.label, this.icon, this.background, this.foreground);
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final _Status status;

  @override
  Widget build(BuildContext context) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 12, color: status.foreground),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: status.foreground, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ]),
      );
}
