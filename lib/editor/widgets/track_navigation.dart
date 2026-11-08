import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../editor_view_state.dart';
import '../ruler.dart';
import '../state/timeline_gestures.dart';
import 'track_drag.dart';

/// Moving around the track without editing it.
///
/// Mouse wheel: with Ctrl it zooms around the cursor, without it scrolls
/// the zoomed track (either wheel axis, so Shift+wheel works too).
///
/// Fingers: one drags the zoomed track and a flick lets it glide on; two
/// pinch to zoom around the point between them while dragging it along.
/// As soon as a second finger lands, the gesture belongs to the track, so
/// a pinch is never taken for a scrub, a trim or a long press under the
/// first finger.
class TrackNavigation extends StatefulWidget {
  const TrackNavigation({
    required this.window,
    required this.trackWidth,
    required this.actions,
    required this.child,
    super.key,
  });

  final TimelineWindow window;

  /// Width of the time part of the track (its left edge is this widget's).
  final double trackWidth;
  final EditorActions actions;
  final Widget child;

  @override
  State<TrackNavigation> createState() => _TrackNavigationState();
}

class _TrackNavigationState extends State<TrackNavigation>
    with SingleTickerProviderStateMixin {
  /// Wheel travel (logical px) that doubles or halves the span.
  static const _doublingTravel = 240.0;

  late final Ticker _glide;
  Simulation? _fling;
  double _flungTo = 0;

  double _lastX = 0;
  double _lastScale = 1;
  int _fingers = 0;

  /// Zoom sent since [TrackNavigation.window] was last rebuilt. Both
  /// fingers' moves usually arrive within one frame; the second must
  /// scroll at the span the first one's zoom left.
  double _unbuiltZoom = 1;

  double get _width => widget.trackWidth;

  @override
  void initState() {
    super.initState();
    _glide = createTicker(_glideStep);
  }

  @override
  void didUpdateWidget(TrackNavigation old) {
    super.didUpdateWidget(old);
    if (widget.window != old.window) _unbuiltZoom = 1;
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _width <= 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final delta = scroll.scrollDelta;
      if (HardwareKeyboard.instance.isControlPressed) {
        widget.actions.onZoom(
          math.pow(2, delta.dy / _doublingTravel).toDouble(),
          (scroll.localPosition.dx / _width).clamp(0.0, 1.0),
          _width,
        );
        return;
      }
      final pixels = delta.dx != 0 ? delta.dx : delta.dy;
      widget.actions.onScrollTimeline(widget.window.span * (pixels / _width));
    });
  }

  void _onStart(ScaleStartDetails details) {
    _stopGliding();
    _lastX = details.localFocalPoint.dx;
    _lastScale = 1;
    _fingers = details.pointerCount;
  }

  void _onUpdate(ScaleUpdateDetails details) {
    if (_width <= 0) return;
    _fingers = math.max(_fingers, details.pointerCount);
    final step = TrackPinch.between(
      span: widget.window.span * _unbuiltZoom,
      trackWidth: _width,
      fromX: _lastX,
      toX: details.localFocalPoint.dx,
      fromScale: _lastScale,
      toScale: details.scale,
    );
    _lastX = details.localFocalPoint.dx;
    _lastScale = details.scale;
    final actions = widget.actions;
    if (step.factor != 1) {
      actions.onZoom(step.factor, step.anchor, _width);
      _unbuiltZoom *= step.factor;
    }
    if (step.scroll != Duration.zero) actions.onScrollTimeline(step.scroll);
  }

  /// A one-finger drag that ends in a flick glides on, slowing the way
  /// Android lists do; a pinch never does.
  void _onEnd(ScaleEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (details.pointerCount > 0 || _fingers != 1) return;
    if (velocity.abs() < kMinFlingVelocity) return;
    _fling = ClampingScrollSimulation(position: 0, velocity: velocity);
    _flungTo = 0;
    _glide.start();
  }

  void _glideStep(Duration elapsed) {
    final fling = _fling;
    if (fling == null || _width <= 0) {
      _stopGliding();
      return;
    }
    final seconds = elapsed.inMicroseconds / 1e6;
    final to = fling.x(seconds);
    final moved = to - _flungTo;
    _flungTo = to;
    if (moved != 0) {
      widget.actions.onScrollTimeline(widget.window.span * (-moved / _width));
    }
    if (fling.isDone(seconds)) _stopGliding();
  }

  void _stopGliding() {
    _fling = null;
    _glide.stop();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: _onSignal,
    onPointerDown: (_) => _stopGliding(),
    child: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _PinchRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
              _PinchRecognizer.new,
              (recognizer) => recognizer
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd,
            ),
      },
      child: widget.child,
    ),
  );
}

/// Pan and pinch for fingers on the screen only, claiming every pointer it
/// tracks the moment it tracks two.
final class _PinchRecognizer extends ScaleGestureRecognizer {
  _PinchRecognizer() : super(supportedDevices: PointerKinds.touch);

  final _down = <int>{};

  /// Touchpad gestures stay with the wheel handling.
  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _down.add(event.pointer);
    if (_down.length > 1) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
    }
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _down.remove(pointer);
    super.rejectGesture(pointer);
  }
}
