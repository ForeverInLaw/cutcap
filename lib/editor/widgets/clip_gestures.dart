import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/edit_list.dart' show ClipEdge, ClipId;
import 'track_drag.dart';

/// Drags on a clip tile.
///
/// With a mouse a drag along the body moves the clip at once, and a drag
/// that starts within [grip] px of an edge in view ([inEdge], [outEdge])
/// trims it; the edges show a resize cursor. With a finger a quick drag
/// belongs to the track (it scrolls), so a long press lifts the clip
/// instead: it is selected, the device gives haptic feedback, and the clip
/// follows the finger until it lifts. Fingers trim through [TrimHandle].
class ClipGestures extends StatefulWidget {
  const ClipGestures({
    required this.id,
    required this.drag,
    required this.inEdge,
    required this.outEdge,
    required this.onLift,
    required this.child,
    super.key,
  });

  final ClipId id;
  final TrackDrag drag;
  final bool inEdge;
  final bool outEdge;

  /// Called when a long press lifts the clip, before it starts moving.
  final VoidCallback onLift;
  final Widget child;

  /// Width of the mouse grip on each edge.
  static const grip = 8.0;

  @override
  State<ClipGestures> createState() => _ClipGesturesState();
}

class _ClipGesturesState extends State<ClipGestures> {
  /// Whether a drag this tile started is still running; a recognizer that
  /// lost the arena must not end someone else's drag.
  bool _dragging = false;

  TrackDrag get _drag => widget.drag;

  void _startMouseDrag(DragStartDetails details) {
    final x = details.localPosition.dx;
    final width = context.size?.width ?? 0;
    _dragging = true;
    if (widget.inEdge && x < ClipGestures.grip) {
      _drag.trimEdge(widget.id, ClipEdge.inPoint, details.globalPosition);
    } else if (widget.outEdge && x > width - ClipGestures.grip) {
      _drag.trimEdge(widget.id, ClipEdge.outPoint, details.globalPosition);
    } else {
      _drag.moveClip(widget.id, details.globalPosition);
    }
  }

  void _lift(LongPressStartDetails details) {
    Feedback.forLongPress(context);
    widget.onLift();
    _dragging = true;
    _drag.moveClip(widget.id, details.globalPosition);
  }

  void _update(Offset global) {
    if (_dragging) _drag.update(global);
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    _drag.end();
  }

  @override
  Widget build(BuildContext context) {
    Widget cursor() => const MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      hitTestBehavior: HitTestBehavior.translucent,
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        GestureDetector(
          supportedDevices: PointerKinds.precise,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _startMouseDrag,
          onHorizontalDragUpdate: (details) => _update(details.globalPosition),
          onHorizontalDragEnd: (_) => _end(),
          onHorizontalDragCancel: _end,
          child: GestureDetector(
            supportedDevices: PointerKinds.touch,
            onLongPressStart: _lift,
            onLongPressMoveUpdate: (details) => _update(details.globalPosition),
            onLongPressEnd: (_) => _end(),
            onLongPressCancel: _end,
            child: widget.child,
          ),
        ),
        if (widget.inEdge)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: ClipGestures.grip,
            child: cursor(),
          ),
        if (widget.outEdge)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: ClipGestures.grip,
            child: cursor(),
          ),
      ],
    );
  }
}

/// The touch target for one edge of the selected clip: [width] px centred
/// on the edge, reaching over the gutter and the neighbour, with nothing
/// drawn (the selected frame marks the clip). It lets every touch through
/// to what lies beneath, so a tap still selects the neighbour and a long
/// press still lifts it; only a horizontal drag trims.
class TrimHandle extends StatefulWidget {
  const TrimHandle({
    required this.id,
    required this.edge,
    required this.drag,
    super.key,
  });

  final ClipId id;
  final ClipEdge edge;
  final TrackDrag drag;

  /// Effective width of the target.
  static const width = 48.0;

  @override
  State<TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<TrimHandle> {
  bool _dragging = false;

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    widget.drag.end();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    supportedDevices: PointerKinds.touch,
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: (details) {
      _dragging = true;
      widget.drag.trimEdge(widget.id, widget.edge, details.globalPosition);
    },
    onHorizontalDragUpdate: (details) {
      if (_dragging) widget.drag.update(details.globalPosition);
    },
    onHorizontalDragEnd: (_) => _end(),
    onHorizontalDragCancel: _end,
  );
}
