import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../domain/frame_rate.dart';
import 'ruler.dart';

/// What the editor screen shows, as plain immutable data. The screen renders
/// it and reports intent through [EditorActions]; it owns no editing logic.
@immutable
final class EditorViewState {
  const EditorViewState({
    this.clips = const [],
    this.position = Duration.zero,
    this.window,
    this.frameRate = const FrameRate(30, 1),
    this.outputSize,
    this.isPlaying = false,
    this.canSplit = false,
    this.canDelete = false,
    this.canUndo = false,
    this.canRedo = false,
    this.canExport = false,
    this.export = const ExportIdle(),
    this.acceptsFileDrop = false,
  });

  /// The track, in sequence order, back to back.
  final List<ClipView> clips;

  /// Playhead time in the sequence.
  final Duration position;

  /// The part of the sequence the track shows; the whole sequence when null.
  final TimelineWindow? window;

  /// Output frame rate (the first clip's), used for every timecode.
  final FrameRate frameRate;

  /// Output frame size in pixels (the first clip's), for the status line.
  final Size? outputSize;

  final bool isPlaying;
  final bool canSplit;
  final bool canDelete;
  final bool canUndo;
  final bool canRedo;
  final bool canExport;
  final ExportStatus export;

  /// Whether files can be dropped onto the window (desktop).
  final bool acceptsFileDrop;

  bool get isEmpty => clips.isEmpty;

  Duration get duration =>
      clips.fold(Duration.zero, (total, clip) => total + clip.duration);

  TimelineWindow get visibleWindow =>
      window ?? TimelineWindow(Duration.zero, duration);
}

/// One clip on the track.
@immutable
final class ClipView {
  const ClipView({
    required this.id,
    required this.name,
    required this.duration,
    this.aspectRatio = 16 / 9,
    this.thumbnails = const [],
    this.isSelected = false,
    this.isJustEdited = false,
    this.isMissing = false,
  });

  final String id;

  /// Source file name.
  final String name;
  final Duration duration;

  /// Display width over height of the source (after rotation); filmstrip
  /// cells take this shape so thumbnails show whole.
  final double aspectRatio;

  /// Filmstrip frames in source order; solid frames are drawn while empty.
  final List<ImageProvider> thumbnails;

  final bool isSelected;

  /// Changed by the last edit; carries the red marker.
  final bool isJustEdited;

  /// The source file is gone; the clip stays but is skipped at export.
  final bool isMissing;
}

/// Where the export stands.
sealed class ExportStatus {
  const ExportStatus();
}

final class ExportIdle extends ExportStatus {
  const ExportIdle();
}

final class ExportRunning extends ExportStatus {
  const ExportRunning(this.progress) : assert(progress >= 0 && progress <= 1);

  /// 0 to 1.
  final double progress;
}

final class ExportDone extends ExportStatus {
  const ExportDone({required this.fileName, this.canShare = false});

  final String fileName;

  /// Whether the platform offers a share sheet (Android).
  final bool canShare;
}

final class ExportFailed extends ExportStatus {
  const ExportFailed(this.reason);

  /// Localized sentence naming the problem.
  final String reason;
}

/// Everything the user can ask the editor to do. Availability lives in
/// [EditorViewState]; these only carry the intent.
@immutable
final class EditorActions {
  const EditorActions({
    required this.onAddVideo,
    required this.onExport,
    required this.onPlayPause,
    required this.onStepBackward,
    required this.onStepForward,
    required this.onSplit,
    required this.onDelete,
    required this.onUndo,
    required this.onRedo,
    required this.onSelectClip,
    required this.onSeek,
    required this.onCancelExport,
    required this.onOpenExport,
    required this.onShareExport,
    required this.onRetryExport,
    required this.onDismissExport,
  });

  final VoidCallback onAddVideo;
  final VoidCallback onExport;
  final VoidCallback onPlayPause;
  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;
  final VoidCallback onSplit;
  final VoidCallback onDelete;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<String> onSelectClip;

  /// Called on every scrub update, latest wins; never awaits the frame.
  final ValueChanged<Duration> onSeek;
  final VoidCallback onCancelExport;
  final VoidCallback onOpenExport;
  final VoidCallback onShareExport;
  final VoidCallback onRetryExport;
  final VoidCallback onDismissExport;
}
