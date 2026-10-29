import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/library_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/reader_settings_provider.dart';
import 'providers/user_data_provider.dart';
import 'screens/main_shell.dart';
import 'services/book_repository.dart';
import 'services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = !AppConfig.bundledFonts;

  // Last-resort logging so a failed async write or stray exception is
  // visible instead of vanishing. Hook a crash reporter in here later.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  final store = LocalStore(await SharedPreferences.getInstance());

  runApp(
    MultiProvider(
      providers: [
        Provider<BookRepository>(
          create: (_) => BookRepository(store),
          dispose: (_, repo) => repo.dispose(),
        ),
        ChangeNotifierProvider(create: (c) => LibraryProvider(c.read<BookRepository>())),
        ChangeNotifierProvider(create: (_) => UserDataProvider(store)),
        ChangeNotifierProvider(create: (_) => ReaderSettingsProvider(store)),
        ChangeNotifierProvider(create: (_) => NotesProvider(store)),
      ],
      child: const NdingApp(),
    ),
  );
}

class NdingApp extends StatelessWidget {
  const NdingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MainShell(),
      );
}
