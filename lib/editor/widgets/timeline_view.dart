import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/edit_list.dart' show ClipEdge;
import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../ruler.dart';
import '../timecode.dart';
import 'clip_gestures.dart';
import 'clip_tile.dart';
import 'control_button.dart';
import 'ruler_view.dart';
import 'track_drag.dart';
import 'track_navigation.dart';

/// How the playhead rule meets the headline timecode: the rule rises
/// [rise] px above the ruler, to a red underline just under the time
/// ([timeWidth] from the left edge); when the playhead stands past the time
/// a hairline carries the underline on to it. Time and rule read as one
/// stroke wherever the playhead is.
@immutable
final class PlayheadTie {
  const PlayheadTie({required this.rise, required this.timeWidth});

  final double rise;
  final double timeWidth;
}

/// Ruler, the single track and the red playhead rule through both, with an
/// add tile fixed at the end of the track.
///
/// Clips are laid out by time across the visible window, back to back with
/// 4 px gutters. Pressing or dragging on the ruler seeks; every update is
/// reported at once and nothing waits for the frame. Dragging a clip (with
/// a finger: after a long press) moves it along the track while its
/// neighbours slide out of the way; dragging a clip's edge trims it (with a
/// finger: the selected clip's, from a 48 dp target). Drags held near
/// either end of the zoomed track scroll it. The wheel and fingers move
/// around the track ([TrackNavigation]). [compact] (phone) stacks clip
/// names over lengths and stretches the ruler to a touch target.
class TimelineView extends StatefulWidget {
  const TimelineView({
    required this.state,
    required this.actions,
    required this.compact,
    required this.tie,
    this.filmHeight = defaultFilmHeight,
    super.key,
  });

  final EditorViewState state;
  final EditorActions actions;
  final bool compact;
  final PlayheadTie tie;
  final double filmHeight;

  static const defaultFilmHeight = 110.0;
  static const _rulerGap = 8.0;
  static const _touchRuler = 56.0;
  static RulerMetrics _ruler(TextScaler scaler, bool compact) =>
      RulerMetrics(scaler, minHeight: compact ? _touchRuler : 0);

  static TrackMetrics _track(TextScaler scaler, bool compact, double film) =>
      TrackMetrics(scaler, filmHeight: film, twoLineLabels: compact);

  /// The view's height at the current text size: top rule, ruler, track.
  static double heightOf(
    BuildContext context, {
    required bool compact,
    double filmHeight = defaultFilmHeight,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    return 1 +
        _ruler(scaler, compact).height +
        _rulerGap +
        _track(scaler, compact, filmHeight).height;
  }

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView>
    with SingleTickerProviderStateMixin {
  TimelineWindow? _lastWindow;
  List<ClipView>? _lastClips;
  TrackSpace? _space;
  late final TrackDrag _drag = TrackDrag(
    vsync: this,
    space: () => _space!,
    actions: () => widget.actions,
  );

  EditorViewState get state => widget.state;
  EditorActions get actions => widget.actions;
  PlayheadTie get tie => widget.tie;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  /// Tiles slide to a new place after an edit (reorder, ripple), but follow
  /// zooming, scrolling and a dragged edge at once, in step with the ruler.
  bool _slides(TimelineWindow window) {
    final navigated =
        window != _lastWindow && identical(state.clips, _lastClips);
    _lastWindow = window;
    _lastClips = state.clips;
    return !state.isTrimming && !navigated;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final filmHeight = widget.filmHeight;
    final tokens = CutcapTokens.of(context);
    final space = CutcapTokens.space;
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = TimelineView._track(scaler, compact, filmHeight);
    final rulerMetrics = TimelineView._ruler(scaler, compact);
    final rulerHeight = rulerMetrics.height;
    const rulerGap = TimelineView._rulerGap;
    final addWidth = compact ? 48.0 : 56.0;
    final trackTop = rulerHeight + rulerGap;
    final filmTop = trackTop + metrics.labelHeight + TrackMetrics.labelGap;
    final window = state.visibleWindow;
    final slides = _slides(window);

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeWidth = constraints.maxWidth - addWidth - space.xs;
        double xOf(Duration time) => window.fractionOf(time) * timeWidth;
        _space = TrackSpace(
          window: window,
          width: timeWidth,
          scrollable: window.span < state.duration,
          box: () => context.findRenderObject()! as RenderBox,
        );
        final motion = CutcapTokens.motion;
        final slide = slides
            ? motion.of(context, motion.standard)
            : Duration.zero;
        final playheadX = xOf(state.position);
        final showPlayhead = playheadX >= 0 && playheadX <= timeWidth;
        Widget ruler(RulerLayer layer) => RulerView(
          window: window,
          rate: state.frameRate,
          layer: layer,
          metrics: rulerMetrics,
        );
        Widget red() => const ColoredBox(color: CutcapTokens.signal);

        return TrackNavigation(
          window: window,
          trackWidth: timeWidth,
          actions: actions,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.ink)),
            ),
            child: SizedBox(
              height: trackTop + metrics.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: timeWidth,
                    height: rulerHeight,
                    child: _Scrubber(
                      state: state,
                      actions: actions,
                      width: timeWidth,
                      child: ruler(RulerLayer.ticks),
                    ),
                  ),
                  for (final (clip, start) in _placed(state.clips))
                    if ((start < window.end &&
                            start + clip.duration > window.start) ||
                        clip.id == _drag.clip)
                      _tile(
                        clip: clip,
                        left: xOf(start),
                        right: xOf(start + clip.duration) - space.xs,
                        timeWidth: timeWidth,
                        top: trackTop,
                        metrics: metrics,
                        slide: slide,
                      ),
                  // Finger targets for the selected clip's edges, over its
                  // neighbours; nothing is drawn.
                  for (final (clip, start) in _placed(state.clips))
                    if (clip.isSelected)
                      for (final (edge, x) in [
                        (ClipEdge.inPoint, xOf(start)),
                        (
                          ClipEdge.outPoint,
                          xOf(start + clip.duration) - space.xs,
                        ),
                      ])
                        if (x >= 0 && x <= timeWidth)
                          Positioned(
                            left: x - TrimHandle.width / 2,
                            width: TrimHandle.width,
                            top: trackTop,
                            height: metrics.height,
                            child: TrimHandle(
                              id: clip.id,
                              edge: edge,
                              drag: _drag,
                            ),
                          ),
                  Positioned(
                    right: 0,
                    top: filmTop,
                    child: ControlButton(
                      icon: Icons.add_sharp,
                      label: AppLocalizations.of(context).addVideo,
                      onPressed: state.canAdd ? actions.onAddVideo : null,
                      size: metrics.filmHeight,
                      width: addWidth,
                    ),
                  ),
                  if (showPlayhead) ...[
                    // The time is underlined; a hairline carries the underline
                    // on to the rule when the playhead stands past the time.
                    Positioned(
                      left: 0,
                      width: tie.timeWidth,
                      top: -tie.rise,
                      height: _rule,
                      child: IgnorePointer(child: red()),
                    ),
                    if (playheadX > tie.timeWidth)
                      Positioned(
                        left: tie.timeWidth,
                        width: playheadX - tie.timeWidth,
                        top: -tie.rise,
                        height: 1,
                        child: IgnorePointer(child: red()),
                      ),
                    Positioned(
                      left: playheadX - _rule / 2,
                      width: _rule,
                      top: -tie.rise,
                      height: tie.rise + trackTop + metrics.height,
                      child: IgnorePointer(child: red()),
                    ),
                    Positioned(
                      left: playheadX - _headSize / 2,
                      width: _headSize,
                      top: 0,
                      height: _headSize,
                      child: IgnorePointer(child: red()),
                    ),
                  ],
                  Positioned(
                    left: 0,
                    top: 0,
                    width: timeWidth,
                    height: rulerHeight,
                    child: IgnorePointer(child: ruler(RulerLayer.labels)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _headSize = 10.0;
  static const _rule = 2.0;

  /// A clip tile cut to the visible window; the parts outside stay hidden
  /// without clipping, so the tile's focus ring is never cut. Tiles slide
  /// to a new place (reorder, ripple) except while an edge is dragged. A
  /// dragged clip scrolled out of view stays built, offstage, so its drag
  /// goes on.
  Widget _tile({
    required ClipView clip,
    required double left,
    required double right,
    required double timeWidth,
    required double top,
    required TrackMetrics metrics,
    required Duration slide,
  }) {
    final visibleLeft = left.clamp(0.0, timeWidth);
    final visibleRight = right.clamp(0.0, timeWidth);
    return AnimatedPositioned(
      key: ValueKey(clip.id),
      duration: slide,
      curve: CutcapTokens.motion.curve,
      left: visibleLeft,
      top: top,
      height: metrics.height,
      width: math.max(1.0, visibleRight - visibleLeft),
      child: Offstage(
        offstage: visibleRight <= visibleLeft,
        child: ClipGestures(
          id: clip.id,
          drag: _drag,
          inEdge: visibleLeft == left,
          outEdge: visibleRight == right,
          onLift: () => actions.onSelectClip(clip.id),
          child: ClipTile(
            clip: clip,
            rate: state.frameRate,
            metrics: metrics,
            hiddenStart: visibleLeft - left,
            filmWidth: math.max(1.0, right - left),
            onSelect: () => actions.onSelectClip(clip.id),
          ),
        ),
      ),
    );
  }

  /// Each clip with its start time in the sequence.
  static Iterable<(ClipView, Duration)> _placed(List<ClipView> clips) sync* {
    var start = Duration.zero;
    for (final clip in clips) {
      yield (clip, start);
      start += clip.duration;
    }
  }
}

/// Turns presses and drags across the ruler into seeks, and exposes the
/// ruler to assistive tech as a slider stepped frame by frame. A finger
/// snaps to cuts from twice as far as a mouse.
class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.state,
    required this.actions,
    required this.width,
    required this.child,
  });

  final EditorViewState state;
  final EditorActions actions;
  final double width;
  final Widget child;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  /// How close to a cut, in pixels, the playhead snaps to it.
  static const _mouseSnap = 8.0;
  static const _touchSnap = 16.0;

  double _snap = _mouseSnap;

  void _press(PointerDeviceKind? kind) =>
      _snap = PointerKinds.isTouch(kind) ? _touchSnap : _mouseSnap;

  void _seekTo(double dx) {
    final window = widget.state.visibleWindow;
    final width = widget.width;
    widget.actions.onScrub(
      window.timeAt(dx / width),
      window.span * (_snap / width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final actions = widget.actions;
    final rate = state.frameRate;
    final frame = rate.frameDuration;
    final previous = state.position - frame;
    return Semantics(
      slider: true,
      label: AppLocalizations.of(context).timeline,
      value: Timecode.full(state.position, rate),
      increasedValue: Timecode.full(state.position + frame, rate),
      decreasedValue: Timecode.full(
        previous.isNegative ? Duration.zero : previous,
        rate,
      ),
      onIncrease: actions.onStepForward,
      onDecrease: actions.onStepBackward,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _press(details.kind);
            _seekTo(details.localPosition.dx);
          },
          onHorizontalDragStart: (details) => _press(details.kind),
          onHorizontalDragUpdate: (details) =>
              _seekTo(details.localPosition.dx),
          child: widget.child,
        ),
      ),
    );
  }
}
