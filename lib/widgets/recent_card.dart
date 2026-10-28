import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import 'common.dart';

/// Compact, full-bleed card for the "Continue reading" row.
class RecentCard extends StatelessWidget {
  const RecentCard({
    super.key,
    required this.book,
    required this.progress,
    required this.onTap,
  });
  static const width = 120.0;
  static const height = 188.0;

  final Book book;
  final ReadingProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BookCover(
                url: book.cover,
                width: width,
                height: height,
                radius: 0,
              ),
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
                        AppColors.ink.withValues(alpha: 0.74),
                        AppColors.ink.withValues(alpha: 0.94),
                      ],
                      stops: const [0, 0.35, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 30, 8, 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ProgressBar(
                          value: progress.percent,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              formatPercent(progress.percent),
                              style: t.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                ' · ${formatTimeLeft(progress.minutesLeft)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
