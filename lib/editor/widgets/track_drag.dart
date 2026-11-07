import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/edit_list.dart' show ClipEdge, ClipId;
import '../editor_view_state.dart';
import '../ruler.dart';
import '../state/timeline_gestures.dart';

/// Pointer kinds the track treats as fingers: they scroll and pinch the
/// track, lift clips with a long press and trim only the selected clip.
/// Every other kind (mouse) drags clips and edges directly.
abstract final class PointerKinds {
  static const touch = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  static const precise = {
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  static bool isTouch(PointerDeviceKind? kind) => touch.contains(kind);
}

/// The track as last laid out: the window it shows, its width in px and
/// where it sits on screen.
@immutable
final class TrackSpace {
  const TrackSpace({
    required this.window,
    required this.width,
    required this.scrollable,
    required this.box,
  });

  final TimelineWindow window;
  final double width;

  /// Whether the track is zoomed in, so there is more sequence to scroll to.
  final bool scrollable;

  /// The render box the track is laid out in, its left edge at time
  /// [TimelineWindow.start].
  final RenderBox Function() box;

  double xOf(Offset global) => box().globalToLocal(global).dx;

  /// Sequence time under a global pointer position.
  Duration timeAt(Offset global) => window.timeAt(xOf(global) / width);
}

/// A drag of a clip (to move it) or of one of its edges (to trim it), the
/// whole drag one undo step. While the pointer is held near either end of
/// the zoomed track, the track scrolls by itself ([EdgeScroll]) and the
/// drag goes on with the time now under the pointer.
///
/// [space] and [actions] are read afresh on every update, so the drag
/// follows the track as it is rebuilt.
final class TrackDrag {
  TrackDrag({
    required TickerProvider vsync,
    required this.space,
    required this.actions,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  final ValueGetter<TrackSpace> space;
  final ValueGetter<EditorActions> actions;

  late final Ticker _ticker;
  _Drag? _drag;
  Offset _pointer = Offset.zero;
  TimelineWindow? _sentFor;
  Duration _lastTick = Duration.zero;

  /// The clip being dragged; its tile is kept built even out of view, so
  /// the drag survives scrolling it away.
  ClipId? get clip => _drag?.id;

  void moveClip(ClipId id, Offset global) {
    _drag = _Move(id);
    _pointer = global;
    actions().onReorderStart(id);
  }

  void trimEdge(ClipId id, ClipEdge edge, Offset global) {
    final track = space();
    _drag = _Trim(
      id,
      edge,
      startX: track.xOf(global),
      startWindow: track.window.start,
      microsecondsPerPixel: track.window.span.inMicroseconds / track.width,
    );
    _pointer = global;
    actions().onTrimStart(id, edge);
  }

  void update(Offset global) {
    if (_drag == null) return;
    _pointer = global;
    _send(space());
    if (!_ticker.isActive && _edgeRate(space()) != 0) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void end() {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    _ticker.stop();
    switch (drag) {
      case _Move():
        actions().onReorderEnd();
      case _Trim():
        actions().onTrimEnd();
    }
  }

  void dispose() => _ticker.dispose();

  double _edgeRate(TrackSpace track) => track.scrollable
      ? EdgeScroll.rate(track.xOf(_pointer), trackWidth: track.width)
      : 0;

  void _send(TrackSpace track) {
    _sentFor = track.window;
    switch (_drag) {
      case _Move():
        actions().onReorderUpdate(track.timeAt(_pointer));
      case final _Trim trim:
        actions().onTrimUpdate(trim.offset(track, _pointer));
      case null:
    }
  }

  /// Each frame: catch the drag up with the track the last scroll left,
  /// then scroll on while the pointer stays near an end.
  void _tick(Duration elapsed) {
    final track = space();
    if (track.window != _sentFor) _send(track);
    final rate = _edgeRate(track);
    if (rate == 0) {
      _ticker.stop();
      return;
    }
    final step = elapsed - _lastTick;
    _lastTick = elapsed;
    if (step > Duration.zero) {
      actions().onScrollTimeline(
        track.window.span * (rate * step.inMicroseconds / 1e6),
      );
    }
  }
}

sealed class _Drag {
  const _Drag(this.id);

  final ClipId id;
}

final class _Move extends _Drag {
  const _Move(super.id);
}

/// An edge drag. The offset is measured at the scale the drag started with
/// (the track holds its scale while an edge moves), plus however far the
/// track has scrolled since.
final class _Trim extends _Drag {
  const _Trim(
    super.id,
    this.edge, {
    required this.startX,
    required this.startWindow,
    required this.microsecondsPerPixel,
  });

  final ClipEdge edge;
  final double startX;
  final Duration startWindow;
  final double microsecondsPerPixel;

  Duration offset(TrackSpace track, Offset pointer) =>
      Duration(
        microseconds: ((track.xOf(pointer) - startX) * microsecondsPerPixel)
            .round(),
      ) +
      (track.window.start - startWindow);
}
