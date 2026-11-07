import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_screen.dart';
import 'editor_shortcuts.dart';
import 'editor_view_state.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';
import 'state/view_state_provider.dart';

/// The editor wired up: [EditorScreen] fed from the editor state, its
/// intents sent to [EditorController], with the preview player's surface
/// and the desktop keyboard shortcuts.
class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorViewStateProvider);
    final controller = ref.watch(editorControllerProvider);
    return EditorShortcuts(
      controller: controller,
      child: EditorScreen(
        state: state,
        actions: _actions(controller),
        // The player starts with the first clip, not with the app.
        preview: state.isEmpty
            ? null
            : ref.watch(previewPlayerProvider).buildView(),
      ),
    );
  }

  static EditorActions _actions(EditorController editor) => EditorActions(
    onAddVideo: () => unawaited(editor.addVideos()),
    // Wired to the export engine by CUTCAP-6.
    onExport: _notYet,
    onPlayPause: editor.togglePlay,
    onStepBackward: () => editor.stepFrame(-1),
    onStepForward: () => editor.stepFrame(1),
    onSplit: editor.split,
    onDelete: editor.deleteSelected,
    onUndo: editor.undo,
    onRedo: editor.redo,
    onSelectClip: editor.select,
    onSeek: editor.seek,
    onClear: editor.clear,
    onTrimStart: editor.beginTrim,
    onTrimUpdate: editor.updateTrim,
    onTrimEnd: editor.endTrim,
    onReorderStart: editor.beginReorder,
    onReorderUpdate: editor.updateReorder,
    onReorderEnd: editor.endReorder,
    onDismissUnreadable: editor.dismissImportProblems,
    onCancelExport: _notYet,
    onOpenExport: _notYet,
    onShareExport: _notYet,
    onRetryExport: _notYet,
    onDismissExport: _notYet,
  );

  static void _notYet() {}
}
