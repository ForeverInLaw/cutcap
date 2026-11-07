import 'package:flutter/widgets.dart';

/// A single-file video player the editor previews through.
///
/// It knows nothing about clips: `SequencePlayback` turns the sequence into
/// opens and seeks on it. The interface exists so a platform can swap the
/// engine (Android may move to ExoPlayer) without touching the editor.
abstract interface class PreviewPlayer {
  /// Loads the file at [path], paused. Completes once it can be sought;
  /// throws [UnplayableMedia] when the engine cannot play the file.
  Future<void> open(String path);

  /// Seeks exactly: the player shows the first frame whose timestamp is at
  /// or after [position]. Completes when the player has taken the seek,
  /// not when the frame is on screen.
  Future<void> seek(Duration position);

  Future<void> play();
  Future<void> pause();

  /// Source time of the current file as playback advances.
  Stream<Duration> get position;

  /// Fires when playback reaches the end of the file.
  Stream<void> get completed;

  /// The surface showing the video, letterboxed on black and upright
  /// whatever the file's rotation.
  Widget buildView();

  Future<void> dispose();
}

/// The player could not load the file at [path], e.g. a container ffprobe
/// reads but the playback engine does not.
final class UnplayableMedia implements Exception {
  const UnplayableMedia(this.path);

  final String path;

  @override
  String toString() => 'The player cannot open $path.';
}
