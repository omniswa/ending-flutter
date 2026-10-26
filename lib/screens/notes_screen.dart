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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
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
                    Text('My Notes', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(notes.length == 1 ? '1 note' : '${notes.length} notes', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  ]),
                ),
                RoundIconButton(icon: Icons.file_upload_outlined, tooltip: 'Import .txt / .md', onTap: () => _import(context)),
              ]),
            ),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
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
                            mainAxisExtent: 190,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (_, i) => _NoteCard(note: notes[i], onTap: () => _open(context, notes[i].id)),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = AppColors.noteColors[note.colorIndex.clamp(0, AppColors.noteColors.length - 1)];
    return SoftCard(
      color: color,
      radius: 22,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(note.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15))),
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (_) async {
                  final notes = context.read<NotesProvider>();
                  final ok = await confirmDialog(context, title: 'Delete note?', message: '"${note.displayTitle}" will be permanently deleted.', action: 'Delete');
                  if (ok) notes.delete(note.id);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: Text(note.body.trim(), overflow: TextOverflow.fade, style: t.bodySmall?.copyWith(color: AppColors.ink.withValues(alpha: 0.75), height: 1.35)),
          ),
          Text(formatDate(note.updatedAt), style: t.labelSmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
