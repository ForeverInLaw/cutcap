import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'clip_tile.dart';
import 'control_button.dart';
import 'ruler_view.dart';

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
/// reported at once and nothing waits for the frame. [compact] (phone)
/// stacks clip names over lengths and stretches the ruler to a touch target.
class TimelineView extends StatelessWidget {
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
  static const _rule = 2.0;

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
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final space = CutcapTokens.space;
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = _track(scaler, compact, filmHeight);
    final rulerMetrics = _ruler(scaler, compact);
    final rulerHeight = rulerMetrics.height;
    const rulerGap = _rulerGap;
    final addWidth = compact ? 48.0 : 56.0;
    final trackTop = rulerHeight + rulerGap;
    final filmTop = trackTop + metrics.labelHeight + TrackMetrics.labelGap;
    final window = state.visibleWindow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeWidth = constraints.maxWidth - addWidth - space.xs;
        double xOf(Duration time) => window.fractionOf(time) * timeWidth;
        final playheadX = xOf(state.position);
        final showPlayhead = playheadX >= 0 && playheadX <= timeWidth;
        Widget ruler(RulerLayer layer) => RulerView(
          window: window,
          rate: state.frameRate,
          layer: layer,
          metrics: rulerMetrics,
        );
        Widget red() => const ColoredBox(color: CutcapTokens.signal);

        return DecoratedBox(
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
                  if (start < window.end &&
                      start + clip.duration > window.start)
                    _tile(
                      clip: clip,
                      left: xOf(start),
                      right: xOf(start + clip.duration) - space.xs,
                      timeWidth: timeWidth,
                      top: trackTop,
                      metrics: metrics,
                    ),
                Positioned(
                  right: 0,
                  top: filmTop,
                  child: ControlButton(
                    icon: Icons.add_sharp,
                    label: AppLocalizations.of(context).addVideo,
                    onPressed: actions.onAddVideo,
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
        );
      },
    );
  }

  static const _headSize = 10.0;

  /// A clip tile cut to the visible window; the parts outside stay hidden
  /// without clipping, so the tile's focus ring is never cut.
  Widget _tile({
    required ClipView clip,
    required double left,
    required double right,
    required double timeWidth,
    required double top,
    required TrackMetrics metrics,
  }) {
    final visibleLeft = math.max(0.0, left);
    final visibleRight = math.min(timeWidth, right);
    return Positioned(
      key: ValueKey(clip.id),
      left: visibleLeft,
      top: top,
      height: metrics.height,
      width: math.max(1.0, visibleRight - visibleLeft),
      child: ClipTile(
        clip: clip,
        rate: state.frameRate,
        metrics: metrics,
        hiddenStart: visibleLeft - left,
        filmWidth: math.max(1.0, right - left),
        onSelect: () => actions.onSelectClip(clip.id),
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
/// ruler to assistive tech as a slider stepped frame by frame.
class _Scrubber extends StatelessWidget {
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

  void _seekTo(double dx) =>
      actions.onSeek(state.visibleWindow.timeAt(dx / width));

  @override
  Widget build(BuildContext context) {
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
          onTapDown: (details) => _seekTo(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              _seekTo(details.localPosition.dx),
          child: child,
        ),
      ),
    );
  }
}
