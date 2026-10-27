import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

/// Cover-first card for the "Continue reading" row.
class RecentCard extends StatelessWidget {
  const RecentCard({super.key, required this.book, required this.progress, required this.onTap});
  static const width = 120.0;
  static const coverHeight = 176.0;

  final Book book;
  final ReadingProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                BookCover(url: book.cover, width: width, height: coverHeight, radius: 14),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_stories_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(formatPercent(progress.percent), style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(textStyle: t.titleSmall, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            ProgressBar(value: progress.percent, minHeight: 5),
            const SizedBox(height: 5),
            Text(formatTimeLeft(progress.minutesLeft),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
