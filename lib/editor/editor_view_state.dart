import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../domain/editor_session.dart';
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
    this.canClear = false,
    this.canAdd = true,
    this.canExport = false,
    this.export = const ExportIdle(),
    this.acceptsFileDrop = false,
    this.unreadableFiles = const [],
    this.sessionProblem,
    this.isTrimming = false,
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
  final bool canClear;

  /// Off while an export runs: the track is locked until it ends.
  final bool canAdd;
  final bool canExport;
  final ExportStatus export;

  /// Whether files can be dropped onto the window (desktop).
  final bool acceptsFileDrop;

  /// Names of picked files that could not be opened; shown until dismissed.
  final List<String> unreadableFiles;

  /// Something went wrong with the autosaved edit; shown until dismissed
  /// (a failed save also until a later one works).
  final SessionProblem? sessionProblem;

  /// A clip edge is being dragged: the track follows the pointer without
  /// animating.
  final bool isTrimming;

  bool get isEmpty => clips.isEmpty;

  /// Whether the status band shows a panel (export or a problem) rather
  /// than the resting summary.
  bool get showsStatusPanel =>
      export is! ExportIdle ||
      unreadableFiles.isNotEmpty ||
      sessionProblem != null;

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
    this.filmstrip,
    this.isSelected = false,
    this.isJustEdited = false,
    this.isMissing = false,
  });

  final ClipId id;

  /// Source file name.
  final String name;
  final Duration duration;

  /// Display width over height of the source (after rotation); filmstrip
  /// cells take this shape so thumbnails show whole.
  final double aspectRatio;

  /// The thumbnail for each filmstrip cell; solid frames are drawn without
  /// one and until it loads.
  final FilmstripFrame? filmstrip;

  final bool isSelected;

  /// Changed by the last edit; carries the red marker.
  final bool isJustEdited;

  /// The source file is gone; the clip stays but is skipped at export.
  final bool isMissing;
}

/// The image for the filmstrip cell that starts [start] into the clip and
/// spans [span] of it, [pixelHeight] device pixels tall.
typedef FilmstripFrame =
    ImageProvider Function(Duration start, Duration span, int pixelHeight);

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
  const ExportFailed(this.problem, {this.detail});

  /// What went wrong, told to the user as a localized headline.
  final ExportProblem problem;

  /// The exporter's own technical account, untranslated (e.g. ffmpeg's
  /// last lines), shown as secondary text under the headline.
  final String? detail;
}

/// Why an export did not produce a file.
enum ExportProblem {
  /// The ffmpeg the export runs on is neither bundled nor on `PATH`.
  exporterMissing,

  /// The chosen file is one of the clips' sources.
  targetIsSource,

  /// The source files of all clips are missing.
  nothingToExport,

  /// No H.264 encoder works on this device.
  noEncoder,

  /// The exporter did not start.
  cannotStart,

  /// The output could not be written or saved.
  cannotWrite,

  /// Another export is still running.
  busy,

  /// Android stopped the export before it was done.
  stopped,

  /// Android's daily time limit for exports ran out.
  timeLimit,

  /// The exporter ran and failed; [ExportFailed.detail] says how.
  failed,
}

/// What went wrong with the autosaved edit.
sealed class SessionProblem {
  const SessionProblem();
}

/// The edit saved by the last run could not be read; the editor started
/// empty. The file was set aside as [keptAs] (a file name), or could not be
/// moved (null).
final class SessionUnreadable extends SessionProblem {
  const SessionUnreadable(this.keptAs);

  final String? keptAs;
}

/// The latest autosave could not be written; the next edit tries again.
final class SessionNotSaved extends SessionProblem {
  const SessionNotSaved();
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
    required this.onScrub,
    required this.onZoom,
    required this.onScrollTimeline,
    required this.onClear,
    required this.onTrimStart,
    required this.onTrimUpdate,
    required this.onTrimEnd,
    required this.onReorderStart,
    required this.onReorderUpdate,
    required this.onReorderEnd,
    required this.onDismissNotice,
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
  final ValueChanged<ClipId> onSelectClip;

  /// Called on every scrub update with the time under the pointer and how
  /// far from a cut the playhead still snaps to it; latest wins, never
  /// awaits the frame.
  final void Function(Duration time, Duration snapTolerance) onScrub;

  /// Ctrl+wheel over the track: zoom by the factor (below 1 zooms in)
  /// around the fraction across the track (px wide) under the cursor.
  final void Function(double factor, double anchor, double trackWidth) onZoom;

  /// The wheel over the zoomed track: scroll it by this much time.
  final ValueChanged<Duration> onScrollTimeline;
  final VoidCallback onClear;

  /// A drag on a clip's edge: start, then the edge's offset in time from
  /// where the drag started, then the end.
  final void Function(ClipId id, ClipEdge edge) onTrimStart;
  final ValueChanged<Duration> onTrimUpdate;
  final VoidCallback onTrimEnd;

  /// A drag along a clip: start, then the sequence time under the
  /// pointer, then the end.
  final ValueChanged<ClipId> onReorderStart;
  final ValueChanged<Duration> onReorderUpdate;
  final VoidCallback onReorderEnd;

  /// Hides the notice the status band shows (files that could not be
  /// added, a problem with the autosaved edit).
  final VoidCallback onDismissNotice;
  final VoidCallback onCancelExport;
  final VoidCallback onOpenExport;
  final VoidCallback onShareExport;
  final VoidCallback onRetryExport;
  final VoidCallback onDismissExport;
}
