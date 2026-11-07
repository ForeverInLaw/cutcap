import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/editor_session.dart';
import '../../media/media_probe.dart';
import '../editor_view_state.dart';
import 'editor_state.dart';
import 'export_notifier.dart';
import 'timeline_zoom.dart';

final editorControllerProvider = Provider<EditorController>(
  EditorController.new,
);

/// Everything the user can do in the editor, across the session, the
/// playhead, the selection and the preview. Buttons, gestures and keyboard
/// shortcuts all call in here; widgets read the state providers.
///
/// Edits and scrubbing pause playback first, and every change of the
/// playhead or the sequence brings the preview to the frame under the
/// playhead. While an export runs the track is locked: edits are ignored
/// so the file matches what the user sees, while scrubbing and playback
/// still work.
final class EditorController {
  EditorController(this._ref);

  final Ref _ref;

  _TrimDrag? _trim;
  ClipId? _reordering;

  SessionNotifier get _session => _ref.read(sessionProvider.notifier);
  EditList get _list => _ref.read(sessionProvider).editList;
  Duration get _playhead => _ref.read(playheadProvider);
  Transport get _transport => _ref.read(transportProvider);
  bool get _locked => _ref.read(exportProvider) is ExportRunning;

  // Adding -----------------------------------------------------------------

  /// Opens the picker and adds what the user chose.
  Future<void> addVideos() async {
    if (_locked) return;
    final paths = await _ref.read(videoPickerProvider)();
    await addFiles(paths);
  }

  /// Probes [paths] and appends the usable ones in the given order as one
  /// undo step; the names of the rest go to [importProblemsProvider].
  Future<void> addFiles(List<String> paths) async {
    if (paths.isEmpty || _locked) return;
    final probe = _ref.read(mediaProbeProvider);
    // A file that fails is reported to the user by name; the rest of the
    // batch goes on.
    Future<({Source? source, String? problem})> probed(String path) async {
      try {
        return (source: await probe.probe(path), problem: null);
      } on MediaProbeException catch (error) {
        return (source: null, problem: error.name);
      }
    }

    final results = await Future.wait(paths.map(probed));
    final sources = [for (final result in results) ?result.source];
    _ref.read(importProblemsProvider.notifier).set([
      for (final result in results) ?result.problem,
    ]);
    // An export may have started while the files were probed.
    if (sources.isEmpty || _locked) return;
    final wasEmpty = _list.clips.isEmpty;
    _session.addSources(sources);
    if (wasEmpty) _seekTo(Duration.zero);
    // Adding a missing file again brings its clips back.
    if (_ref.read(missingSourcesProvider).isNotEmpty) await checkSources();
  }

  void dismissImportProblems() =>
      _ref.read(importProblemsProvider.notifier).set(const []);

  // Session ----------------------------------------------------------------

  /// Starts the editor: restores the last edit, then appends [files], the
  /// ones the app was opened with ("Open with", or the share that started
  /// it on Android), then each batch of [shared] videos in turn as it
  /// arrives (shares while running); completes when [shared] closes.
  /// Called once at launch.
  Future<void> launch(
    List<String> files, {
    Stream<List<String>> shared = const Stream.empty(),
  }) async {
    await restoreSession();
    await addFiles(files);
    await for (final batch in shared) {
      await addFiles(batch);
    }
  }

  /// Brings back the edit saved by the last run, flags sources whose file
  /// is gone and from then on autosaves every edit.
  Future<void> restoreSession() async {
    final saved = await _ref.read(sessionStoreProvider).load();
    _session.restore(saved);
    if (_list.clips.isEmpty) return;
    await checkSources();
    _seekTo(Duration.zero);
  }

  /// Rechecks that every source file is still there, e.g. when the app
  /// comes back to the foreground; a file that came back is unflagged.
  Future<void> checkSources() async {
    final exists = _ref.read(sourceExistsProvider);
    final sources = _list.sources.values.toList();
    final present = await Future.wait(sources.map((s) => exists(s.path)));
    final missing = {
      for (final (i, source) in sources.indexed)
        if (!present[i]) source.id,
    };
    final current = _ref.read(missingSourcesProvider);
    if (missing.length != current.length || !missing.containsAll(current)) {
      _ref.read(missingSourcesProvider.notifier).set(Set.unmodifiable(missing));
    }
  }

  // Editing ----------------------------------------------------------------

  void select(ClipId id) => _ref.read(selectionProvider.notifier).set(id);

  /// Splits the clip under the playhead; the right-hand part is marked.
  void split() {
    _edit(() {
      _session.split(_playhead);
      return _list.locate(_playhead)?.clip.id;
    });
  }

  /// Removes the selected clip; the clips after it close the gap.
  void deleteSelected() {
    final selected = _ref.read(selectionProvider);
    if (selected == null || !_list.clips.any((c) => c.id == selected)) return;
    _edit(() {
      _session.remove(selected);
      return null;
    });
  }

  void undo() => _edit(() {
    _session.undo();
    return null;
  });

  void redo() => _edit(() {
    _session.redo();
    return null;
  });

  /// Empties the track, as one undoable step.
  void clear() => _edit(() {
    _session.clear();
    return null;
  });

  /// Runs [change], marks the clip it returns, drops a selection the
  /// change removed, and keeps the playhead inside the sequence.
  void _edit(ClipId? Function() change) {
    if (_locked) return;
    _pauseIfPlaying();
    final before = _ref.read(sessionProvider);
    final edited = change();
    if (identical(before, _ref.read(sessionProvider))) return;
    _ref.read(justEditedProvider.notifier).set(edited);
    _afterEdit();
  }

  void _afterEdit() {
    final selected = _ref.read(selectionProvider);
    if (selected != null && !_list.clips.any((clip) => clip.id == selected)) {
      _ref.read(selectionProvider.notifier).set(null);
    }
    _seekTo(_playhead);
  }

  // Trimming ---------------------------------------------------------------

  /// Starts dragging [edge] of clip [id]; the whole drag is one undo step.
  void beginTrim(ClipId id, ClipEdge edge) {
    if (_locked) return;
    _pauseIfPlaying();
    final clip = _list.clips.firstWhere((clip) => clip.id == id);
    _trim = (
      id: id,
      edge: edge,
      from: edge == ClipEdge.inPoint ? clip.inPoint : clip.outPoint,
    );
    _session.beginGesture();
    _ref.read(timelineEndProvider.notifier).set(_list.duration);
  }

  /// Moves the dragged edge by [delta] of source time from where the drag
  /// started, snapped to a frame, and previews the frame under the edge.
  void updateTrim(Duration delta) {
    final trim = _trim;
    if (trim == null) return;
    _session.trim(trim.id, trim.edge, trim.from + delta);
    final clip = _list.clips.firstWhere((clip) => clip.id == trim.id);
    final timelineEnd = _ref.read(timelineEndProvider.notifier);
    if (_list.duration > (_ref.read(timelineEndProvider) ?? Duration.zero)) {
      timelineEnd.set(_list.duration);
    }
    _ref
        .read(sequencePlaybackProvider)
        .showSource(
          _list.sourceOf(clip),
          trim.edge == ClipEdge.inPoint
              ? clip.inPoint
              : clip.outPoint - const Duration(microseconds: 1),
        );
  }

  void endTrim() {
    final trim = _trim;
    if (trim == null) return;
    _trim = null;
    _ref.read(timelineEndProvider.notifier).set(null);
    _endGesture(trim.id);
  }

  // Reordering -------------------------------------------------------------

  /// Starts dragging clip [id] along the track; the whole drag is one undo
  /// step.
  void beginReorder(ClipId id) {
    if (_locked) return;
    _pauseIfPlaying();
    _reordering = id;
    _session.beginGesture();
  }

  /// Puts the dragged clip where the pointer, at sequence time [pointer],
  /// now stands: after every other clip whose centre it has passed. The
  /// centres are those of the track as it is now, so a clip that has just
  /// moved stays put until the pointer clearly goes back.
  void updateReorder(Duration pointer) {
    final id = _reordering;
    if (id == null) return;
    var index = 0;
    var start = Duration.zero;
    for (final clip in _list.clips) {
      if (clip.id != id && start + clip.duration ~/ 2 < pointer) index++;
      start += clip.duration;
    }
    _session.move(id, index);
  }

  void endReorder() {
    final id = _reordering;
    if (id == null) return;
    _reordering = null;
    _endGesture(id);
  }

  void _endGesture(ClipId id) {
    final changed = _session.gestureChanged;
    _session.endGesture();
    if (changed) _ref.read(justEditedProvider.notifier).set(id);
    _afterEdit();
  }

  // Transport --------------------------------------------------------------

  /// Moves the playhead to [time] and shows its frame; pauses playback.
  void seek(Duration time) {
    _pauseIfPlaying();
    _seekTo(time);
  }

  /// Seeks to [time] under the pointer on the ruler, snapping to a cut (or
  /// either end of the sequence) within [snapTolerance] of it.
  void scrub(Duration time, Duration snapTolerance) {
    var cut = Duration.zero;
    var nearest = cut;
    for (final clip in _list.clips) {
      cut += clip.duration;
      if ((cut - time).abs() < (nearest - time).abs()) nearest = cut;
    }
    seek((nearest - time).abs() <= snapTolerance ? nearest : time);
  }

  // Timeline ---------------------------------------------------------------

  /// Zooms the track by [factor] (below 1 zooms in) around [anchor], the
  /// fraction across the track ([trackWidth] px) under the cursor.
  void zoomTimeline(double factor, double anchor, double trackWidth) => _ref
      .read(timelineZoomProvider.notifier)
      .zoom(factor, anchor: anchor, trackWidth: trackWidth);

  /// Scrolls the zoomed track [delta] along the sequence.
  void scrollTimeline(Duration delta) =>
      _ref.read(timelineZoomProvider.notifier).scroll(delta);

  /// Steps the playhead [frames] frames (negative: back), on the frame grid
  /// of the clip under it, across clip boundaries.
  void stepFrame(int frames) {
    _pauseIfPlaying();
    var time = _playhead;
    for (var i = 0; i < frames.abs(); i++) {
      time = frames > 0 ? _nextFrame(time) : _previousFrame(time);
    }
    _seekTo(time);
  }

  void togglePlay() => _transport == Transport.paused ? playForward() : pause();

  void playForward() {
    if (_list.clips.isEmpty || _transport == Transport.forward) return;
    if (_playhead >= _list.duration) _setPlayhead(Duration.zero);
    _ref.read(transportProvider.notifier).set(Transport.forward);
    unawaited(_ref.read(sequencePlaybackProvider).play(_list, _playhead));
  }

  void playReverse() {
    if (_list.clips.isEmpty || _transport == Transport.reverse) return;
    _ref.read(transportProvider.notifier).set(Transport.reverse);
    _ref.read(sequencePlaybackProvider).reverse(_list, _playhead);
  }

  void pause() {
    _ref.read(transportProvider.notifier).set(Transport.paused);
    unawaited(_ref.read(sequencePlaybackProvider).pause());
  }

  void _pauseIfPlaying() {
    if (_transport != Transport.paused) pause();
  }

  /// Sets the playhead, kept inside the sequence, and shows its frame.
  void _seekTo(Duration time) {
    _setPlayhead(time);
    // A clip whose file is gone has no frame to show; the player would
    // only wait for it to load.
    final clip = _list.locate(_playhead)?.clip;
    if (clip != null &&
        _ref.read(missingSourcesProvider).contains(clip.sourceId)) {
      return;
    }
    _ref.read(sequencePlaybackProvider).show(_list, _playhead);
  }

  /// Sets the playhead, kept inside the sequence, and keeps it in view.
  void _setPlayhead(Duration time) {
    final end = _list.duration;
    final kept = time.isNegative ? Duration.zero : (time > end ? end : time);
    _ref.read(playheadProvider.notifier).set(kept);
    _ref.read(timelineZoomProvider.notifier).reveal(kept);
  }

  /// Start of the frame after the one under [time]: the next clip's first
  /// frame past a clip's last; the last frame's start at the very end.
  Duration _nextFrame(Duration time) {
    final list = _list;
    final hit = list.locate(time);
    if (hit == null) return _lastFrameStart(list) ?? Duration.zero;
    final clip = hit.clip;
    final grid = list.sourceOf(clip).frameRate;
    final next = grid.frameStart(grid.frameAt(hit.sourceTime) + 1);
    if (next < clip.outPoint) return list.sequenceTimeOf(clip.id, next);
    final end = list.startOf(clip.id) + clip.duration;
    return end < list.duration ? end : _lastFrameStart(list)!;
  }

  /// Start of the frame before the one under [time], or of the clip's own
  /// frame when [time] is past the end.
  Duration _previousFrame(Duration time) {
    final list = _list;
    final hit = list.locate(time);
    if (hit == null) return _lastFrameStart(list) ?? Duration.zero;
    final clip = hit.clip;
    final grid = list.sourceOf(clip).frameRate;
    final previous = grid.frameAt(hit.sourceTime) - 1;
    if (previous >= grid.frameAt(clip.inPoint)) {
      return list.sequenceTimeOf(clip.id, grid.frameStart(previous));
    }
    final start = list.startOf(clip.id);
    if (start == Duration.zero) return Duration.zero;
    return _frameStartAt(list, start - const Duration(microseconds: 1));
  }

  Duration? _lastFrameStart(EditList list) => list.clips.isEmpty
      ? null
      : _frameStartAt(list, list.duration - const Duration(microseconds: 1));

  /// Sequence time where the frame under [time] starts.
  Duration _frameStartAt(EditList list, Duration time) {
    final hit = list.locate(time)!;
    final grid = list.sourceOf(hit.clip).frameRate;
    final start = grid.frameStart(grid.frameAt(hit.sourceTime));
    return list.sequenceTimeOf(
      hit.clip.id,
      start < hit.clip.inPoint ? hit.clip.inPoint : start,
    );
  }
}

/// An edge drag in progress: which edge, and its source time at the start.
typedef _TrimDrag = ({ClipId id, ClipEdge edge, Duration from});
