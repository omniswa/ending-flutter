import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/common.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await context.read<NotesProvider>().importFiles();
      if (n > 0) messenger.showSnackBar(SnackBar(content: Text('Imported $n ${n == 1 ? 'note' : 'notes'}')));
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t import that file.')));
    }
  }

  void _open(BuildContext context, [String? id]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(noteId: id)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final notes = provider.notes;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(context),
        tooltip: 'New note',
        elevation: 2,
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notes', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(notes.length == 1 ? '1 note' : '${notes.length} notes', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  ]),
                ),
                RoundIconButton(icon: Icons.file_upload_outlined, tooltip: 'Import .txt / .md', onTap: () => _import(context)),
              ]),
            ),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.sage))
                  : notes.isEmpty
                      ? EmptyState(
                          icon: Icons.edit_note_rounded,
                          title: 'Your notebook is empty',
                          message: 'Jot down thoughts while you read, or import text files.',
                          actionLabel: 'Import notes',
                          onAction: () => _import(context),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisExtent: 176,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (_, i) => _NoteCard(
                            key: ValueKey(notes[i].id),
                            note: notes[i],
                            onTap: () => _open(context, notes[i].id),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({super.key, required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  void _delete(BuildContext context) {
    final provider = context.read<NotesProvider>();
    final removed = provider.delete(note.id);
    if (removed == null) return;
    showUndoSnack(context, 'Deleted "${removed.displayTitle}"', () => provider.save(removed));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = AppColors.noteColors[note.colorIndex.clamp(0, AppColors.noteColors.length - 1)];
    return SoftCard(
      color: color,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: onTap,
      onLongPress: () => _delete(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(note.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.muted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (_) => _delete(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                      SizedBox(width: 12),
                      Text('Delete'),
                    ]),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(note.body.trim(), overflow: TextOverflow.fade, style: t.bodySmall?.copyWith(color: AppColors.ink.withValues(alpha: 0.72), height: 1.4)),
            ),
          ),
          Text(formatDate(note.updatedAt), style: t.labelSmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
