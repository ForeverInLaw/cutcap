import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'editor/state/editor_state.dart';
import 'platform/incoming_files.dart';

/// [args] are the files Explorer's "Open with" (or a command line) hands
/// the app; they are appended to the restored edit in the order given.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [launchFilesProvider.overrideWithValue(incomingFiles(args))],
      child: const CutcapApp(),
    ),
  );
}
