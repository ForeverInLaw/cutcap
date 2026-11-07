import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'editor/state/editor_state.dart';
import 'platform/android_documents.dart';
import 'platform/incoming_files.dart';

/// [args] are the files Explorer's "Open with" (or a command line) hands
/// the app; on Android the videos of the share that started it take their
/// place. They are appended to the restored edit in the order given.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final launchFiles = Platform.isAndroid
      ? await AndroidDocuments.launchShares()
      : incomingFiles(args);
  runApp(
    ProviderScope(
      overrides: [launchFilesProvider.overrideWithValue(launchFiles)],
      child: const CutcapApp(),
    ),
  );
}
