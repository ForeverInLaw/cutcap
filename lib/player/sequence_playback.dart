import 'dart:async';

import '../domain/editor_session.dart';
import 'preview_player.dart';

/// Plays an [EditList] through one [PreviewPlayer], which only knows single
/// files: it opens the source under the playhead, seeks it exactly (ADR
/// 0002) and, during playback, jumps to the next clip's source and in point
/// when a clip reaches its last frame. A short hitch at those jumps is
/// accepted.
///
/// Seeks never queue: while the player is busy with one, newer requests
/// replace each other and only the latest is carried out next.
///
/// Sequence time flows out through [onPosition] while playing; [onEnded]
/// fires when playback stops by itself at either end of the sequence;
/// [onUnplayable] names a file the player could not open.
final class SequencePlayback {
  SequencePlayback(
    this._player, {
    required this.onPosition,
    required this.onEnded,
    required this.onUnplayable,
  }) {
    _subscriptions = [
      _player.position.listen(_onSourcePosition),
      _player.completed.listen((_) => _onSourceCompleted()),
    ];
  }

  final PreviewPlayer _player;
  final void Function(Duration sequenceTime) onPosition;
  final void Function() onEnded;
  final void Function(String path) onUnplayable;

  late final List<StreamSubscription<Object?>> _subscriptions;

  /// Step of reverse playback.
  static const reverseTick = Duration(milliseconds: 40);

  String? _openPath;
  bool _playerPlaying = false;

  /// The latest frame asked for and not yet sent to the player.
  _Target? _pending;
  bool _busy = false;

  /// The clip playing forward, when playing.
  _Run? _run;
  Timer? _reverse;

  /// Shows the frame under sequence [time], paused.
  void show(EditList list, Duration time) {
    final hit = list.locate(time);
    if (hit == null) return;
    _request(_Target(list.sourceOf(hit.clip).path, hit.seekTime));
  }

  /// Shows the frame of [source] under [sourceTime], paused, e.g. the frame
  /// under a clip edge being trimmed.
  void showSource(Source source, Duration sourceTime) =>
      _request(_Target(source.path, source.frameRate.seekTarget(sourceTime)));

  /// Plays forward from sequence time [from]; from the start when [from] is
  /// at or past the end.
  Future<void> play(EditList list, Duration from) async {
    _stopReverse();
    final start = list.locate(from) ?? list.locate(Duration.zero);
    if (start == null) return;
    _run = _Run(list, start.clip);
    _request(
      _Target(list.sourceOf(start.clip).path, start.seekTime, play: true),
    );
  }

  /// Plays backwards from sequence time [from] by seeking along in real
  /// time, latest frame first, until the start of the sequence.
  void reverse(EditList list, Duration from) {
    unawaited(pause());
    var time = from > list.duration ? list.duration : from;
    _reverse = Timer.periodic(reverseTick, (timer) {
      time -= reverseTick;
      if (time <= Duration.zero) {
        time = Duration.zero;
        _stopReverse();
      }
      show(list, time);
      onPosition(time);
      if (time == Duration.zero) onEnded();
    });
  }

  /// Stops either way of playing; the frame on screen stays.
  Future<void> pause() async {
    _stopReverse();
    _run = null;
    if (_pending case final pending? when pending.play) {
      _pending = pending.paused;
    }
    if (_playerPlaying) {
      _playerPlaying = false;
      await _player.pause();
    }
  }

  void dispose() {
    _stopReverse();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void _stopReverse() {
    _reverse?.cancel();
    _reverse = null;
  }

  void _request(_Target target) {
    _pending = target;
    if (!_busy) unawaited(_drain());
  }

  /// Carries out the latest request, then whatever replaced it meanwhile.
  Future<void> _drain() async {
    _busy = true;
    try {
      for (var target = _pending; target != null; target = _pending) {
        _pending = null;
        // A broken file must not wedge later requests; report and go on.
        try {
          await _apply(target);
        } on UnplayableMedia catch (error) {
          _openPath = null;
          onUnplayable(error.path);
        } on Object catch (error, stack) {
          _openPath = null;
          Zone.current.handleUncaughtError(error, stack);
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _apply(_Target target) async {
    if (_playerPlaying && (!target.play || target.pauseFirst)) {
      _playerPlaying = false;
      await _player.pause();
    }
    if (_openPath != target.path) {
      _openPath = null;
      await _player.open(target.path);
      _openPath = target.path;
    }
    await _player.seek(target.seekTime);
    if (target.play && !_playerPlaying) {
      _playerPlaying = true;
      await _player.play();
    }
  }

  void _onSourcePosition(Duration position) {
    final run = _run;
    if (run == null || _busy) return;
    final clip = run.clip;
    if (!run.armed) {
      // Until the player reports a time inside the clip, positions may
      // still come from before the last jump.
      final frame = run.list.sourceOf(clip).frameRate.frameDuration;
      if (position < clip.inPoint - frame || position >= clip.outPoint) return;
      run.armed = true;
    }
    final offset = position < clip.inPoint
        ? Duration.zero
        : position - clip.inPoint;
    onPosition(run.start + (offset < clip.duration ? offset : clip.duration));
    if (position >= run.lastFrameTarget) _advance(run);
  }

  void _onSourceCompleted() {
    final run = _run;
    if (run != null && !_busy) _advance(run);
  }

  /// Moves playback on from the clip [run] is in: straight through when the
  /// next clip continues the same source, else with a jump; stops after the
  /// last clip.
  void _advance(_Run run) {
    final clips = run.list.clips;
    final index = clips.indexWhere((clip) => clip.id == run.clip.id);
    if (index + 1 >= clips.length) {
      _run = null;
      unawaited(pause());
      onPosition(run.list.duration);
      onEnded();
      return;
    }
    final current = run.clip;
    final next = clips[index + 1];
    final continues =
        next.sourceId == current.sourceId && next.inPoint == current.outPoint;
    _run = _Run(run.list, next, armed: continues);
    if (continues) return;
    final source = run.list.sourceOf(next);
    _request(
      _Target(
        source.path,
        source.frameRate.seekTarget(next.inPoint),
        play: true,
        pauseFirst: true,
      ),
    );
  }
}

/// A frame to bring up: [seekTime] in the file at [path], then play or not.
final class _Target {
  const _Target(
    this.path,
    this.seekTime, {
    this.play = false,
    this.pauseFirst = false,
  });

  final String path;
  final Duration seekTime;
  final bool play;

  /// Hold the current frame while jumping instead of playing past it.
  final bool pauseFirst;

  _Target get paused => _Target(path, seekTime);
}

/// The clip being played forward and where it sits in the sequence.
final class _Run {
  _Run(this.list, this.clip, {this.armed = false})
    : start = list.startOf(clip.id),
      lastFrameTarget = list
          .sourceOf(clip)
          .frameRate
          .seekTarget(clip.outPoint - const Duration(microseconds: 1));

  final EditList list;
  final Clip clip;
  final Duration start;

  /// Once the source reaches this time, the clip's last frame is showing.
  final Duration lastFrameTarget;

  /// Whether the player has reported a time inside this clip yet.
  bool armed;
}
