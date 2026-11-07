import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/editor_controller.dart';
import 'state/editor_state.dart';

/// Ties the session to the app's life: at start it restores the saved edit
/// and appends the files the app was opened with, then the videos shared
/// into it while it runs (Android); and it rechecks the source files
/// whenever the app comes back to the foreground, where the user may have
/// moved or deleted some.
class SessionKeeper extends ConsumerStatefulWidget {
  const SessionKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionKeeper> createState() => _SessionKeeperState();
}

class _SessionKeeperState extends ConsumerState<SessionKeeper> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final editor = ref.read(editorControllerProvider);
    unawaited(
      editor.launch(
        ref.read(launchFilesProvider),
        shared: ref.read(sharedVideosProvider),
      ),
    );
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(editor.checkSources()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
