import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 8,
  });
  final String url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.18),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (width * 3).round(),
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, __) => const ColoredBox(color: AppColors.chip),
          errorWidget: (_, __, ___) => const ColoredBox(
            color: AppColors.chip,
            child: Icon(Icons.menu_book_rounded, color: AppColors.muted),
          ),
        ),
      ),
    ),
  );
}

/// A raised card: soft layered shadow, generous radius.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = AppColors.surface,
    this.radius = 10,
    this.onTap,
    this.onLongPress,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: AppColors.softShadow,
    ),
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(
          width: 4,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onDark = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Frosted-glass style for use on top of the gradient [ScreenHeader].
  final bool onDark;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 22),
    style: IconButton.styleFrom(
      backgroundColor: onDark
          ? Colors.white.withValues(alpha: 0.18)
          : AppColors.chip,
      foregroundColor: onDark ? Colors.white : AppColors.ink,
      fixedSize: const Size(44, 44),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.sageSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.sage),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: t.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
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

/// Gradient banner at the top of each tab: title, subtitle, optional
/// trailing action and optional bottom content (e.g. a search field).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.letterSpacing = 0,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.terracotta.withValues(alpha: 0.18),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: t.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: letterSpacing,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: t.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  if (bottom != null) ...[const SizedBox(height: 18), bottom!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin reading-progress bar used on book cards.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.terracotta,
    this.backgroundColor = AppColors.chip,
    this.minHeight = 4,
  });
  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(minHeight),
    child: LinearProgressIndicator(
      value: value.clamp(0.02, 1.0).toDouble(),
      minHeight: minHeight,
      backgroundColor: backgroundColor,
      color: color,
    ),
  );
}

/// Shows a short snackbar with an UNDO action, replacing any current one.
void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
