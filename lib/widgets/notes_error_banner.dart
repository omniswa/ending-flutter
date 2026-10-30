import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notes_provider.dart';

class NotesErrorBanner extends StatelessWidget {
  const NotesErrorBanner({super.key});

  @override
  Widget build(BuildContext context) => Consumer<NotesProvider>(
    builder: (context, notes, _) {
      final message = notes.errorMessage;
      if (message == null) return const SizedBox.shrink();

      return MaterialBanner(
        leading: const Icon(Icons.warning_amber_rounded),
        content: Text(message),
        actions: [
          TextButton(onPressed: notes.retry, child: Text(notes.retryLabel)),
        ],
      );
    },
  );
}
