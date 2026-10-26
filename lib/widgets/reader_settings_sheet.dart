import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/reader_prefs.dart';
import '../providers/reader_settings_provider.dart';

Future<void> showReaderSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReaderSettingsSheet(),
    );

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReaderSettingsProvider>();
    final prefs = provider.prefs;
    final t = Theme.of(context).textTheme;

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.muted, fontWeight: FontWeight.w700)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Reading settings', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: provider.reset, child: const Text('Reset')),
            ]),
            label('Theme'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final th in ReaderTheme.values)
                  _ThemeSwatch(theme: th, selected: th == prefs.theme, onTap: () => provider.update(prefs.copyWith(theme: th))),
              ],
            ),
            label('Font'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in ReaderFont.values)
                  ChoiceChip(
                    selected: f == prefs.font,
                    showCheckmark: false,
                    label: Text(f.family, style: GoogleFonts.getFont(f.family, color: f == prefs.font ? Colors.white : AppColors.ink)),
                    onSelected: (_) => provider.update(prefs.copyWith(font: f)),
                  ),
              ],
            ),
            label('Alignment'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TextAlign>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left_rounded), tooltip: 'Left'),
                  ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center_rounded), tooltip: 'Center'),
                  ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right_rounded), tooltip: 'Right'),
                  ButtonSegment(value: TextAlign.justify, icon: Icon(Icons.format_align_justify_rounded), tooltip: 'Justify'),
                ],
                selected: {prefs.align},
                onSelectionChanged: (s) => provider.update(prefs.copyWith(align: s.first)),
              ),
            ),
            _SliderRow(
              title: 'Text size',
              value: prefs.fontSize,
              min: ReaderPrefs.minFontSize,
              max: ReaderPrefs.maxFontSize,
              display: '${prefs.fontSize.round()} pt',
              icon: Icons.text_fields_rounded,
              onChanged: (v) => provider.update(prefs.copyWith(fontSize: v.roundToDouble())),
            ),
            _SliderRow(
              title: 'Line height',
              value: prefs.lineHeight,
              min: ReaderPrefs.minLineHeight,
              max: ReaderPrefs.maxLineHeight,
              display: prefs.lineHeight.toStringAsFixed(1),
              icon: Icons.format_line_spacing_rounded,
              onChanged: (v) => provider.update(prefs.copyWith(lineHeight: (v * 10).round() / 10)),
            ),
            _SliderRow(
              title: 'Margins',
              value: prefs.margin,
              min: ReaderPrefs.minMargin,
              max: ReaderPrefs.maxMargin,
              display: '${prefs.margin.round()} px',
              icon: Icons.width_normal_rounded,
              onChanged: (v) => provider.update(prefs.copyWith(margin: v.roundToDouble())),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});
  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.bg,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.terracotta : Colors.black12, width: selected ? 3 : 1),
              ),
              child: Text('Aa', style: TextStyle(color: theme.fg, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            const SizedBox(height: 6),
            Text(theme.label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.title, required this.value, required this.min, required this.max, required this.display, required this.icon, required this.onChanged});
  final String title;
  final double value;
  final double min;
  final double max;
  final String display;
  final IconData icon;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(display, style: t.labelLarge?.copyWith(color: AppColors.terracotta, fontWeight: FontWeight.w700)),
          ]),
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
