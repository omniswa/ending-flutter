import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/common.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});
  final String? noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final NotesProvider _notes;
  late final TextEditingController _title;
  late final TextEditingController _body;
  Note? _note;
  int _color = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _notes = context.read<NotesProvider>();
    _note = widget.noteId == null ? null : _notes.byId(widget.noteId!);
    _color = _note?.colorIndex ?? 0;
    _title = TextEditingController(text: _note?.title ?? '');
    _body = TextEditingController(text: _note?.body ?? '');
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {}); // refresh word count
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  /// Saves unless the note is brand new and still empty.
  void _save() {
    _debounce?.cancel();
    final title = _title.text.trim();
    final body = _body.text;
    if (_note == null && title.isEmpty && body.trim().isEmpty) return;
    _note = (_note ?? Note.create()).copyWith(
      title: title,
      body: body,
      colorIndex: _color,
      updatedAt: DateTime.now(),
    );
    _notes.save(_note!);
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    final ok = await confirmDialog(context, title: 'Delete note?', message: 'This can\'t be undone.', action: 'Delete');
    if (!ok) return;
    _debounce?.cancel();
    if (_note != null) _notes.delete(_note!.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bg = AppColors.noteColors[_color];
    final words = RegExp(r'\S+').allMatches(_body.text).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          actions: [
            if (_note != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete'),
            IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.check_rounded), tooltip: 'Done'),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
                ),
                Expanded(
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: t.bodyLarge?.copyWith(height: 1.55),
                    decoration: const InputDecoration(hintText: 'Start writing…', border: InputBorder.none),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    for (var i = 0; i < AppColors.noteColors.length; i++)
                      GestureDetector(
                        onTap: () {
                          setState(() => _color = i);
                          _save();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.noteColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(color: i == _color ? AppColors.ink : Colors.black26, width: i == _color ? 2 : 1),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text('$words ${words == 1 ? 'word' : 'words'}', style: t.labelMedium?.copyWith(color: AppColors.muted)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
