import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/editor_session.dart';
import '../ruler.dart';
import 'editor_state.dart';

/// The part of the sequence the track shows once zoomed in; null while it
/// shows the whole sequence, which then grows and shrinks with the edit.
final timelineZoomProvider = NotifierProvider<TimelineZoom, TimelineWindow?>(
  TimelineZoom.new,
);

/// Zooms and scrolls the track and keeps the playhead in view. The window
/// is kept inside the sequence as it is now; zooming out to the whole
/// sequence returns to following it.
final class TimelineZoom extends Notifier<TimelineWindow?> {
  /// The deepest zoom: one frame (of the first clip) this many pixels wide,
  /// so the ruler marks and labels every frame.
  static const maxFramePixels = 120.0;

  @override
  TimelineWindow? build() => null;

  EditList get _list => ref.read(sessionProvider).editList;

  /// Zooms by [factor] (below 1 zooms in) around [anchor], the fraction
  /// across a track [trackWidth] px wide where the cursor is.
  void zoom(
    double factor, {
    required double anchor,
    required double trackWidth,
  }) {
    final list = _list;
    final total = list.duration;
    if (list.clips.isEmpty) return;
    final frame = list.sourceOf(list.clips.first).frameRate.frameDuration;
    final from = state?.within(total) ?? TimelineWindow(Duration.zero, total);
    final zoomed = from.zoomedBy(
      factor,
      anchor: anchor,
      total: total,
      minSpan: frame * (trackWidth / maxFramePixels),
    );
    state = zoomed.span >= total ? null : zoomed;
  }

  /// Moves the zoomed track [delta] along the sequence.
  void scroll(Duration delta) {
    final window = state;
    if (window != null) state = window.scrolledBy(delta, total: _list.duration);
  }

  /// Turns the page when [time] (the playhead) leaves the zoomed track.
  void reveal(Duration time) {
    final window = state;
    if (window == null) return;
    final total = _list.duration;
    final revealed = window.within(total).revealing(time, total: total);
    if (revealed != window) state = revealed;
  }
}
