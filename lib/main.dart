import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'editor/state/editor_controller.dart';
import 'platform/incoming_files.dart';

/// [args] are the files Explorer's "Open with" (or a command line) hands
/// the app; they are appended to the track in the order given.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const CutcapApp()),
  );
  unawaited(
    container.read(editorControllerProvider).addFiles(incomingFiles(args)),
  );
}
