import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/editor_session.dart';
import '../editor_view_state.dart';
import '../ruler.dart';
import 'editor_state.dart';

/// The track as the screen draws it. Rebuilt only when the edit, the
/// selection or the marked clip change, not as the playhead moves.
final clipViewsProvider = Provider<List<ClipView>>((ref) {
  final list = ref.watch(sessionProvider.select((s) => s.editList));
  final selected = ref.watch(selectionProvider);
  final edited = ref.watch(justEditedProvider);
  ClipView view(Clip clip) {
    final source = list.sourceOf(clip);
    final size = _displaySize(source);
    return ClipView(
      id: clip.id,
      name: p.basename(source.path),
      duration: clip.duration,
      aspectRatio: size.width / size.height,
      isSelected: clip.id == selected,
      isJustEdited: clip.id == edited,
    );
  }

  return List.unmodifiable(list.clips.map(view));
});

/// Everything [EditorViewState] needs, each piece read narrowly.
final editorViewStateProvider = Provider<EditorViewState>((ref) {
  final list = ref.watch(sessionProvider.select((s) => s.editList));
  final canUndo = ref.watch(sessionProvider.select((s) => s.canUndo));
  final canRedo = ref.watch(sessionProvider.select((s) => s.canRedo));
  final position = ref.watch(playheadProvider);
  final canSplit = ref.watch(
    sessionProvider.select((s) => !identical(s.split(position), s)),
  );
  final selected = ref.watch(selectionProvider);
  final timelineEnd = ref.watch(timelineEndProvider);
  final first = list.clips.isEmpty ? null : list.sourceOf(list.clips.first);
  return EditorViewState(
    clips: ref.watch(clipViewsProvider),
    position: position,
    window: timelineEnd == null
        ? null
        : TimelineWindow(
            Duration.zero,
            timelineEnd > list.duration ? timelineEnd : list.duration,
          ),
    frameRate: first?.frameRate ?? const FrameRate(30, 1),
    outputSize: first == null ? null : _displaySize(first),
    isPlaying: ref.watch(
      transportProvider.select((transport) => transport != Transport.paused),
    ),
    canSplit: canSplit,
    canDelete: selected != null && list.clips.any((c) => c.id == selected),
    canUndo: canUndo,
    canRedo: canRedo,
    canClear: list.clips.isNotEmpty,
    canExport: list.clips.isNotEmpty,
    unreadableFiles: ref.watch(importProblemsProvider),
    isTrimming: timelineEnd != null,
  );
});

/// Frame size of [source] as shown upright.
Size _displaySize(Source source) {
  final (:width, :height) = source.resolution;
  return source.rotation % 180 == 0
      ? Size(width.toDouble(), height.toDouble())
      : Size(height.toDouble(), width.toDouble());
}
