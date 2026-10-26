import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

class RecentCard extends StatelessWidget {
  const RecentCard({super.key, required this.book, required this.progress, required this.onTap});
  final Book book;
  final ReadingProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(10),
      radius: 18,
      onTap: onTap,
      child: Row(
        children: [
          BookCover(url: book.cover, width: 60, height: 90, radius: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 6),
                Text('${formatPercent(progress.percent)} · ${formatTimeLeft(progress.minutesLeft)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.percent.clamp(0.02, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.chip,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(height: 8),
                PillButton(label: 'Continue Reading', onPressed: onTap, filled: false, height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const recentGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 280,
  mainAxisExtent: 112,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
);
