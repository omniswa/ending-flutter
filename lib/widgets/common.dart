import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.url, required this.width, required this.height, this.radius = 12});
  final String url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(color: AppColors.chip),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: AppColors.chip,
              child: Icon(Icons.menu_book_rounded, color: AppColors.muted),
            ),
          ),
        ),
      );
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = AppColors.surface, this.radius = 20, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(width: 36, height: 3, decoration: BoxDecoration(color: AppColors.terracotta, borderRadius: BorderRadius.circular(2))),
              ],
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.badge = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.chip,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 22),
                  if (badge)
                    const Positioned(top: 11, right: 12, child: CircleAvatar(radius: 4, backgroundColor: AppColors.terracotta)),
                ],
              ),
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: AppColors.sage),
            ),
            const SizedBox(height: 20),
            Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: t.bodyMedium?.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped primary action with trailing arrow.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.filled = true, this.height = 42});
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.ink;
    return Material(
      color: filled ? AppColors.sage : AppColors.chip,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: filled ? 15 : 13)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: filled ? 18 : 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, required String action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
