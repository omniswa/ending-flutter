import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showQuoteCard(
  BuildContext context, {
  required String quote,
  required String bookTitle,
  required int chapter,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _QuoteCardDialog(quote: quote, bookTitle: bookTitle, chapter: chapter),
);

class _QuoteCardDialog extends StatefulWidget {
  const _QuoteCardDialog({
    required this.quote,
    required this.bookTitle,
    required this.chapter,
  });

  final String quote;
  final String bookTitle;
  final int chapter;

  @override
  State<_QuoteCardDialog> createState() => _QuoteCardDialogState();
}

class _QuoteCardDialogState extends State<_QuoteCardDialog> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('The quote card could not be rendered.');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      Uint8List bytes;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('The quote card image could not be encoded.');
        }
        bytes = data.buffer.asUint8List();
      } finally {
        image.dispose();
      }

      final safeTitle = widget.bookTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Download quote card',
        fileName: 'quote-card-${safeTitle.isEmpty ? 'book' : safeTitle}.png',
        bytes: bytes,
      );
      if (!mounted) return;
      if (saved != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Quote card saved')));
      } else {
        setState(() => _saving = false);
      }
    } on Object catch (error, stackTrace) {
      debugPrint('Saving quote card failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save that quote card.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardSize = (size.width - 64)
        .clamp(200.0, 380.0)
        .toDouble()
        .clamp(0.0, size.height - 220)
        .toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quote card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: cardSize,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _QuoteCard(
                    quote: widget.quote,
                    bookTitle: widget.bookTitle,
                    chapter: widget.chapter,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Download square PNG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.bookTitle,
    required this.chapter,
  });

  final String quote;
  final String bookTitle;
  final int chapter;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Colors.white),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth * 0.075;
        final verticalPadding = constraints.maxHeight * 0.065;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A PASSAGE TO REMEMBER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF667085),
                        fontSize: constraints.maxWidth * 0.026,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: constraints.maxHeight * 0.035),
              Container(
                width: constraints.maxWidth * 0.14,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: constraints.maxHeight * 0.035),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, quoteConstraints) {
                    final fontSize = _fittingFontSize(
                      context,
                      quoteConstraints,
                    );
                    return Center(
                      child: Text(
                        quote,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fraunces(
                          color: const Color(0xFF202124),
                          fontSize: fontSize,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: constraints.maxHeight * 0.035),
              Text(
                bookTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF202124),
                  fontSize: constraints.maxWidth * 0.038,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: constraints.maxHeight * 0.025),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CHAPTER ${chapter + 1}',
                      style: TextStyle(
                        color: const Color(0xFF667085),
                        fontSize: constraints.maxWidth * 0.025,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '3NDING',
                    style: TextStyle(
                      color: const Color(0xFF667085),
                      fontSize: constraints.maxWidth * 0.03,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  double _fittingFontSize(BuildContext context, BoxConstraints constraints) {
    final textDirection = Directionality.of(context);
    for (var size = 27.0; size >= 14; size -= 0.5) {
      final painter = TextPainter(
        text: TextSpan(
          text: quote,
          style: GoogleFonts.fraunces(
            fontSize: size,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: textDirection,
      )..layout(maxWidth: constraints.maxWidth);
      if (painter.height <= constraints.maxHeight) return size;
    }
    return 14;
  }
}
