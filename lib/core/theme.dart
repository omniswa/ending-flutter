import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const cream = Color(0xFFF7F3EA);
  static const surface = Color(0xFFFFFDF8);
  static const sage = Color(0xFF5E6B4F);
  static const terracotta = Color(0xFFB5703F);
  static const ink = Color(0xFF1F2A2A);
  static const muted = Color(0xFF7C7A72);
  static const chip = Color(0xFFF0EBE0);
  static const danger = Color(0xFFB3412F);

  static const noteColors = <Color>[
    Color(0xFFFFF4D6),
    Color(0xFFE3EBD9),
    Color(0xFFF6DFD0),
    Color(0xFFDDE8EC),
    Color(0xFFEADFF0),
    Color(0xFFFFFDF8),
  ];
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.sage,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.sage,
          onPrimary: Colors.white,
          secondary: AppColors.terracotta,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    // outfitTextTheme loads each weight's real font file; applying only the
    // regular family name would fake bold for every w600-w800 style.
    final text = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.sage.withValues(alpha: 0.12),
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall!.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: selected ? AppColors.sage : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.sage
                : AppColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.chip,
        selectedColor: AppColors.sage,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
      ),
    );
  }
}
