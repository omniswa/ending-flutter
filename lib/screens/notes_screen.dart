import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/common.dart';
import '../widgets/note_export.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await context.read<NotesProvider>().importFiles();
      if (n > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text('Imported $n ${n == 1 ? 'note' : 'notes'}')),
        );
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t import that file.')),
      );
    }
  }

  Future<void> _exportAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await context.read<NotesProvider>().exportAllNotes();
      if (count != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exported $count ${count == 1 ? 'note' : 'notes'}'),
          ),
        );
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t export your notes.')),
      );
    }
  }

  void _open(BuildContext context, [String? id]) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(noteId: id)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final notes = provider.notes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: provider.loading ? null : () => _open(context),
        tooltip: 'New note',
        elevation: 6,
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Notes',
              subtitle: notes.length == 1 ? '1 note' : '${notes.length} notes',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notes.isNotEmpty)
                    RoundIconButton(
                      icon: Icons.archive_outlined,
                      tooltip: 'Export all notes as ZIP',
                      onDark: true,
                      onTap: () => _exportAll(context),
                    ),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: Icons.file_upload_outlined,
                    tooltip: 'Import .txt / .md',
                    onDark: true,
                    onTap: () => _import(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.sage),
                    )
                  : notes.isEmpty
                  ? EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'Your notebook is empty',
                      message: 'Jot down thoughts while you read, or import text files.',
                      actionLabel: 'Import notes',
                      onAction: () => _import(context),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisExtent: 196,
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
    showUndoSnack(
      context,
      'Deleted "${removed.displayTitle}"',
      () => provider.save(removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = AppColors
        .noteColors[note.colorIndex.clamp(0, AppColors.noteColors.length - 1)];
    return SoftCard(
      color: color,
      radius: 4,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
      onTap: onTap,
      onLongPress: () => _delete(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    note.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      textStyle: t.titleMedium,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.2,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'More',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (v) {
                    if (v == 'export') {
                      exportNote(context, title: note.title, body: note.body);
                    }
                    if (v == 'delete') _delete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.ios_share_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Export'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 12),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                note.body.trim(),
                overflow: TextOverflow.fade,
                style: t.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 9,
                  color: AppColors.ink.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatTimestamp(note.updatedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.55),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
