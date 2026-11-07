import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/editor_session.dart';
import '../editor_view_state.dart';
import '../ruler.dart';
import 'editor_state.dart';
import 'export_notifier.dart';
import 'thumbnails.dart';
import 'timeline_zoom.dart';

/// The track as the screen draws it. Rebuilt only when the edit, the
/// selection or the marked clip change, not as the playhead moves.
final clipViewsProvider = Provider<List<ClipView>>((ref) {
  final list = ref.watch(sessionProvider.select((s) => s.editList));
  final selected = ref.watch(selectionProvider);
  final edited = ref.watch(justEditedProvider);
  final missing = ref.watch(missingSourcesProvider);
  final thumbnails = ref.watch(thumbnailCacheProvider);
  ClipView view(Clip clip) {
    final source = list.sourceOf(clip);
    final size = _displaySize(source);
    final isMissing = missing.contains(clip.sourceId);
    return ClipView(
      id: clip.id,
      name: source.name,
      duration: clip.duration,
      aspectRatio: size.width / size.height,
      isSelected: clip.id == selected,
      isJustEdited: clip.id == edited,
      isMissing: isMissing,
      filmstrip: thumbnails == null || isMissing
          ? null
          : filmstripOf(thumbnails, clip, source),
    );
  }

  return List.unmodifiable(list.clips.map(view));
});

/// Everything [EditorViewState] needs, each piece read narrowly. While an
/// export runs every edit is off (see [EditorController]).
final editorViewStateProvider = Provider<EditorViewState>((ref) {
  final export = ref.watch(exportProvider);
  final editable = export is! ExportRunning;
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
    window: _window(
      zoom: ref.watch(timelineZoomProvider),
      total: list.duration,
      timelineEnd: timelineEnd,
    ),
    frameRate: first?.frameRate ?? const FrameRate(30, 1),
    outputSize: first == null ? null : _displaySize(first),
    isPlaying: ref.watch(
      transportProvider.select((transport) => transport != Transport.paused),
    ),
    canSplit: editable && canSplit,
    canDelete:
        editable && selected != null && list.clips.any((c) => c.id == selected),
    canUndo: editable && canUndo,
    canRedo: editable && canRedo,
    canClear: editable && list.clips.isNotEmpty,
    canAdd: editable,
    canExport: editable && list.clips.isNotEmpty,
    export: export,
    // Drops from Explorer; Android has no desktop to drag from.
    acceptsFileDrop: defaultTargetPlatform == TargetPlatform.windows,
    unreadableFiles: ref.watch(importProblemsProvider),
    isTrimming: timelineEnd != null,
  );
});

/// What the track shows: the zoomed window kept inside the sequence, or the
/// whole sequence (null). While an edge is dragged the sequence counts as
/// reaching at least [timelineEnd], so the scale holds still.
TimelineWindow? _window({
  required TimelineWindow? zoom,
  required Duration total,
  required Duration? timelineEnd,
}) {
  final end = timelineEnd != null && timelineEnd > total ? timelineEnd : total;
  if (zoom != null) return zoom.within(end);
  return timelineEnd == null ? null : TimelineWindow(Duration.zero, end);
}

/// Frame size of [source] as shown upright.
Size _displaySize(Source source) {
  final (:width, :height) = source.resolution;
  return source.rotation % 180 == 0
      ? Size(width.toDouble(), height.toDouble())
      : Size(height.toDouble(), width.toDouble());
}
