import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReaderTheme {
  paper('Paper', Color(0xFFFBF8F1), Color(0xFF2B2B2B)),
  sepia('Sepia', Color(0xFFF1E4C8), Color(0xFF4A3A28)),
  dusk('Dusk', Color(0xFF1E2224), Color(0xFFD7D3CA)),
  black('Black', Color(0xFF000000), Color(0xFFB8B8B8));

  const ReaderTheme(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
  bool get isDark => bg.computeLuminance() < 0.3;
}

enum ReaderFont {
  literata('Literata'),
  merriweather('Merriweather'),
  lora('Lora'),
  inter('Inter'),
  atkinson('Atkinson Hyperlegible');

  const ReaderFont(this.family);
  final String family;

  TextStyle get style => this == atkinson
      ? const TextStyle(fontFamily: 'AtkinsonHyperlegible')
      : GoogleFonts.getFont(family);
}

@immutable
class ReaderPrefs {
  const ReaderPrefs({
    this.theme = ReaderTheme.paper,
    this.font = ReaderFont.literata,
    this.fontSize = 18,
    this.align = TextAlign.left,
    this.lineHeight = 1.6,
    this.margin = 24,
  });

  factory ReaderPrefs.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((e) => e.name == name, orElse: () => fallback);
    double num_(String key, double def, double lo, double hi) =>
        ((j[key] as num?)?.toDouble() ?? def).clamp(lo, hi).toDouble();

    return ReaderPrefs(
      theme: pick(ReaderTheme.values, j['theme'], ReaderTheme.paper),
      font: pick(ReaderFont.values, j['font'], ReaderFont.literata),
      fontSize: num_('fontSize', 18, minFontSize, maxFontSize),
      align: pick(TextAlign.values, j['align'], TextAlign.left),
      lineHeight: num_('lineHeight', 1.6, minLineHeight, maxLineHeight),
      margin: num_('margin', 24, minMargin, maxMargin),
    );
  }

  static const minFontSize = 12.0, maxFontSize = 34.0;
  static const minLineHeight = 1.2, maxLineHeight = 2.4;
  static const minMargin = 8.0, maxMargin = 56.0;

  final ReaderTheme theme;
  final ReaderFont font;
  final double fontSize;
  final TextAlign align;
  final double lineHeight;
  final double margin;

  TextStyle get textStyle => font.style.copyWith(
        fontSize: fontSize,
        height: lineHeight,
        color: theme.fg,
      );

  ReaderPrefs copyWith({
    ReaderTheme? theme,
    ReaderFont? font,
    double? fontSize,
    TextAlign? align,
    double? lineHeight,
    double? margin,
  }) =>
      ReaderPrefs(
        theme: theme ?? this.theme,
        font: font ?? this.font,
        fontSize: fontSize ?? this.fontSize,
        align: align ?? this.align,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'font': font.name,
        'fontSize': fontSize,
        'align': align.name,
        'lineHeight': lineHeight,
        'margin': margin,
      };
}
