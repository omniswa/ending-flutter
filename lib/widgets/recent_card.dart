import 'package:flutter/material.dart';

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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: book.cover, width: width, height: coverHeight),
            const SizedBox(height: 10),
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ProgressBar(value: progress.percent),
            const SizedBox(height: 5),
            Text(formatTimeLeft(progress.minutesLeft),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
