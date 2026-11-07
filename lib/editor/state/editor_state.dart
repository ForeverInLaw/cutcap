import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/editor_session.dart';
import '../../media/ffprobe_media_probe.dart';
import '../../media/media_probe.dart';
import '../../player/media_kit_preview_player.dart';
import '../../player/preview_player.dart';
import '../../player/sequence_playback.dart';

/// The edit and its undo history.
final sessionProvider = NotifierProvider<SessionNotifier, EditorSession>(
  SessionNotifier.new,
);

/// The clip the user picked on the track, if any.
final selectionProvider = NotifierProvider<Slot<ClipId?>, ClipId?>(
  () => Slot(null),
);

/// The clip the last edit changed; it carries the red marker.
final justEditedProvider = NotifierProvider<Slot<ClipId?>, ClipId?>(
  () => Slot(null),
);

/// Playhead time in the sequence.
final playheadProvider = NotifierProvider<Slot<Duration>, Duration>(
  () => Slot(Duration.zero),
);

/// Which way the preview is playing.
final transportProvider = NotifierProvider<Slot<Transport>, Transport>(
  () => Slot(Transport.paused),
);

/// Names of the files the last add could not open.
final importProblemsProvider =
    NotifierProvider<Slot<List<String>>, List<String>>(() => Slot(const []));

/// Sources whose file is gone; their clips are skipped at export.
final missingSourcesProvider =
    NotifierProvider<Slot<Set<SourceId>>, Set<SourceId>>(() => Slot(const {}));

/// While a clip edge is dragged, the end of the time span the track keeps
/// showing, so the scale holds still under the pointer; null otherwise.
final timelineEndProvider = NotifierProvider<Slot<Duration?>, Duration?>(
  () => Slot(null),
);

/// The preview engine. Defaults to media_kit; tests override it.
final previewPlayerProvider = Provider<PreviewPlayer>((ref) {
  final player = MediaKitPreviewPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

final mediaProbeProvider = Provider<MediaProbe>(
  (ref) => const FfprobeMediaProbe(),
);

/// Asks the user for videos; paths come back in the picker's order.
final videoPickerProvider = Provider<Future<List<String>> Function()>(
  (ref) => _pickVideos,
);

Future<List<String>> _pickVideos() async {
  const videos = XTypeGroup(
    label: 'video',
    extensions: ['mp4', 'mov', 'm4v', 'mkv', 'webm', 'avi', '3gp'],
    mimeTypes: ['video/*'],
    uniformTypeIdentifiers: ['public.movie'],
  );
  final files = await openFiles(acceptedTypeGroups: const [videos]);
  return [for (final file in files) file.path];
}

/// Drives [previewPlayerProvider] along the sequence and feeds the playhead
/// back while playing.
final sequencePlaybackProvider = Provider<SequencePlayback>((ref) {
  final playback = SequencePlayback(
    ref.watch(previewPlayerProvider),
    onPosition: (time) => ref.read(playheadProvider.notifier).set(time),
    onEnded: () => ref.read(transportProvider.notifier).set(Transport.paused),
    // Reported like a file that could not be added; the clip stays, since
    // ffmpeg may still export it.
    onUnplayable: (path) {
      final problems = ref.read(importProblemsProvider);
      final name = p.basename(path);
      if (!problems.contains(name)) {
        ref.read(importProblemsProvider.notifier).set([...problems, name]);
      }
    },
  );
  ref.onDispose(playback.dispose);
  return playback;
});

enum Transport { paused, forward, reverse }

/// A provider value that is simply set.
final class Slot<T> extends Notifier<T> {
  Slot(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// Holds the [EditorSession] and runs its commands.
///
/// A drag is one undo step: [beginGesture] keeps the session as it was, each
/// [trim] or [move] during the gesture is applied to that kept session
/// rather than stacked on the last one, and [endGesture] lets go of it.
final class SessionNotifier extends Notifier<EditorSession> {
  EditorSession? _gestureOrigin;

  @override
  EditorSession build() => const EditorSession();

  EditorSession get _base => _gestureOrigin ?? state;

  void addSources(List<Source> sources) => state = state.addSources(sources);
  void split(Duration time) => state = state.split(time);
  void remove(ClipId id) => state = state.remove(id);
  void clear() => state = state.clear();
  void undo() => state = state.undo();
  void redo() => state = state.redo();

  void beginGesture() => _gestureOrigin = state;
  void endGesture() => _gestureOrigin = null;

  void trim(ClipId id, ClipEdge edge, Duration sourceTime) =>
      state = _base.trim(id, edge, sourceTime);

  void move(ClipId id, int index) => state = _base.move(id, index);

  /// Whether the session differs from the one the gesture started from.
  bool get gestureChanged => !identical(_gestureOrigin, state);
}
