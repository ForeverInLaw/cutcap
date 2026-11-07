import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_screen.dart';
import 'editor_shortcuts.dart';
import 'editor_view_state.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';
import 'state/export_notifier.dart';
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
        actions: _actions(controller, ref.read(exportProvider.notifier)),
        // The player starts with the first clip, not with the app.
        preview: state.isEmpty
            ? null
            : ref.watch(previewPlayerProvider).buildView(),
      ),
    );
  }

  static EditorActions _actions(
    EditorController editor,
    ExportNotifier export,
  ) => EditorActions(
    onAddVideo: () => unawaited(editor.addVideos()),
    onExport: () => unawaited(export.start()),
    onPlayPause: editor.togglePlay,
    onStepBackward: () => editor.stepFrame(-1),
    onStepForward: () => editor.stepFrame(1),
    onSplit: editor.split,
    onDelete: editor.deleteSelected,
    onUndo: editor.undo,
    onRedo: editor.redo,
    onSelectClip: editor.select,
    onScrub: editor.scrub,
    onZoom: editor.zoomTimeline,
    onScrollTimeline: editor.scrollTimeline,
    onClear: editor.clear,
    onTrimStart: editor.beginTrim,
    onTrimUpdate: editor.updateTrim,
    onTrimEnd: editor.endTrim,
    onReorderStart: editor.beginReorder,
    onReorderUpdate: editor.updateReorder,
    onReorderEnd: editor.endReorder,
    onDismissUnreadable: editor.dismissImportProblems,
    onCancelExport: export.cancel,
    onOpenExport: export.open,
    // Android only, with CUTCAP-10; Windows never offers Share.
    onShareExport: () {},
    onRetryExport: () => unawaited(export.retry()),
    onDismissExport: export.dismiss,
  );
}
