import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/notes_provider.dart';

/// Asks which format to export in, then saves a single note to a file.
///
/// Takes the title/body directly (not a Note) so the editor can export what's
/// on screen even if the debounce hasn't saved it yet.
Future<void> exportNote(BuildContext context, {required String title, required String body}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notes = context.read<NotesProvider>();

  if (title.trim().isEmpty && body.trim().isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('This note is empty — nothing to export.')));
    return;
  }

  final format = await showModalBottomSheet<NoteExportFormat>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Export note', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final f in NoteExportFormat.values)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: AppColors.sageSoft, shape: BoxShape.circle),
                  child: Icon(f == NoteExportFormat.markdown ? Icons.tag_rounded : Icons.notes_rounded, color: AppColors.sage),
                ),
                title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Save as ${f.extension} file'),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    ),
  );
  if (format == null) return;

  try {
    final saved = await notes.exportNote(title: title, body: body, format: format);
    if (saved) messenger.showSnackBar(const SnackBar(content: Text('Note exported')));
  } on Object {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t export that note.')));
  }
}
