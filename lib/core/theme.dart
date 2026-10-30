import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle? googleFontStyleWithWeight(TextStyle? style, FontWeight weight) {
  if (style == null) return null;
  final fontFamilyFallback = style.fontFamilyFallback;
  if (fontFamilyFallback == null || fontFamilyFallback.isEmpty) {
    return style.copyWith(fontWeight: weight);
  }
  final fontFamily = fontFamilyFallback.first;
  return GoogleFonts.getFont(fontFamily, textStyle: style, fontWeight: weight);
}

abstract final class AppColors {
  static const cream = Color(0xFFFAF8F4); // page background
  static const surface = Color(0xFFFFFFFF); // cards, sheets
  static const sage = Color(0xFF4F5D45); // primary
  static const terracotta = Color(0xFFB5703F); // accent: progress, favorites
  static const ink = Color(0xFF1C2321);
  static const muted = Color(0xFF8A877E);
  static const chip = Color(0xFFF1EEE7); // quiet fills
  static const line = Color(0xFFE8E4DA); // hairline borders
  static const danger = Color(0xFFB3412F);
  static const sageDark = Color(0xFF334029); // gradient end
  static const sageSoft = Color(0xFFE4EADB); // tinted fills
  static const terracottaSoft = Color(0xFFF6E4D5);

  /// Brand gradient used on hero surfaces.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sage, sageDark],
  );

  /// Soft, layered elevation for cards.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static const noteColors = <Color>[
    Color(0xFFFFF6DC),
    Color(0xFFE6EDDD),
    Color(0xFFF8E3D6),
    Color(0xFFE0EAEE),
    Color(0xFFEDE3F2),
    Color(0xFFFFFFFF),
  ];

  /// Order the swatches appear in the note editor: white first.
  static const noteColorOrder = <int>[5, 0, 1, 2, 3, 4];
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
          outlineVariant: AppColors.line,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    // Inter for UI text; a serif for large titles gives the app a bookish
    // voice without decorating anything.
    final ui = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    TextStyle? serif(TextStyle? s) => s == null
        ? null
        : GoogleFonts.fraunces(
            textStyle: s,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: AppColors.ink,
          );
    final text = ui.copyWith(
      displaySmall: serif(ui.displaySmall),
      headlineLarge: serif(ui.headlineLarge),
      headlineMedium: serif(ui.headlineMedium),
      headlineSmall: serif(ui.headlineSmall),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: googleFontStyleWithWeight(
          text.titleLarge,
          FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.sageSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return googleFontStyleWithWeight(
            text.labelMedium,
            selected ? FontWeight.w600 : FontWeight.w500,
          )!.copyWith(color: selected ? AppColors.sage : AppColors.muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.sage
                : AppColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFFF0C9A8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.chip,
        selectedColor: AppColors.sage,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          textStyle: googleFontStyleWithWeight(
            text.labelLarge,
            FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          textStyle: googleFontStyleWithWeight(
            text.labelLarge,
            FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.sage),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.sage,
        thumbColor: AppColors.sage,
        inactiveTrackColor: AppColors.chip,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    );
  }
}
