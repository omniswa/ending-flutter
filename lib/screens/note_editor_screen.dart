import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/common.dart';
import '../widgets/note_export.dart';
import '../widgets/notes_error_banner.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});
  final String? noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  late final NotesProvider _notes;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final ValueNotifier<int> _wordCount;
  late String _lastObservedTitle;
  late String _lastObservedBody;
  Note? _note;
  int _color = Note.defaultColorIndex;
  Timer? _debounce;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notes = context.read<NotesProvider>();
    _note = widget.noteId == null ? null : _notes.byId(widget.noteId!);
    _color = (_note?.colorIndex ?? Note.defaultColorIndex).clamp(
      0,
      AppColors.noteColors.length - 1,
    );
    _title = TextEditingController(text: _note?.title ?? '');
    _body = TextEditingController(text: _note?.body ?? '');
    _wordCount = ValueNotifier(_countWords(_body.text));
    _lastObservedTitle = _title.text;
    _lastObservedBody = _body.text;
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _save();
    _wordCount.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _save();
    }
  }

  void _onChanged() {
    final titleChanged = _title.text != _lastObservedTitle;
    final bodyChanged = _body.text != _lastObservedBody;
    if (!titleChanged && !bodyChanged) return;

    _lastObservedTitle = _title.text;
    _lastObservedBody = _body.text;
    if (bodyChanged) _wordCount.value = _countWords(_body.text);

    if (!_hasUnsavedChanges) {
      _debounce?.cancel();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  bool get _hasUnsavedChanges =>
      _title.text.trim() != (_note?.title.trim() ?? '') ||
      _body.text != (_note?.body ?? '') ||
      _color != (_note?.colorIndex ?? Note.defaultColorIndex);

  int _countWords(String text) => RegExp(r'\S+').allMatches(text).length;

  void _save() {
    _debounce?.cancel();
    if (_deleted) return;
    final title = _title.text.trim();
    final body = _body.text;
    if (_note == null && title.isEmpty && body.trim().isEmpty) return;
    if (!_hasUnsavedChanges) return;
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
    final ok = await confirmDialog(
      context,
      title: 'Delete note?',
      message: 'This can\'t be undone.',
      action: 'Delete',
    );
    if (!ok) return;
    _debounce?.cancel();
    _deleted = true;
    if (_note != null) _notes.delete(_note!.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bg = AppColors.noteColors[_color];

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          actions: [
            IconButton(
              onPressed: () =>
                  exportNote(context, title: _title.text, body: _body.text),
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Export',
            ),
            if (_note != null)
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
              ),
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Done',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                const NotesErrorBanner(),
                TextField(
                  controller: _title,
                  minLines: 1,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: googleFontStyleWithWeight(
                    t.headlineSmall,
                    FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
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
                    decoration: const InputDecoration(
                      hintText: 'Start writing…',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      for (final i in AppColors.noteColorOrder)
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
                              border: Border.all(
                                color: i == _color
                                    ? AppColors.ink
                                    : Colors.black26,
                                width: i == _color ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: _wordCount,
                        builder: (context, words, _) => Text(
                          '$words ${words == 1 ? 'word' : 'words'}',
                          style: t.labelMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
