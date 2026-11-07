import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'clip_tile.dart';
import 'control_button.dart';
import 'ruler_view.dart';

/// Ruler, the single track and the red playhead rule through both, with an
/// add tile fixed at the end of the track.
///
/// Clips are laid out by time across the visible window, back to back with
/// 4 px gutters. Pressing or dragging on the ruler seeks; every update is
/// reported at once and nothing waits for the frame.
///
/// The playhead rule starts [playheadLead] px above the ruler so it reaches
/// the headline timecode's baseline: the time and the rule read as one.
class TimelineView extends StatelessWidget {
  const TimelineView({
    required this.state,
    required this.actions,
    required this.compact,
    required this.playheadLead,
    super.key,
  });

  final EditorViewState state;
  final EditorActions actions;
  final bool compact;
  final double playheadLead;

  static const filmHeight = 110.0;
  static const _rulerGap = 8.0;

  /// The view's height at the current text size: top rule, ruler, track.
  static double heightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 1 +
        RulerMetrics(scaler).height +
        _rulerGap +
        TrackMetrics(scaler, filmHeight: filmHeight).height;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final space = CutcapTokens.space;
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = TrackMetrics(scaler, filmHeight: filmHeight);
    final rulerHeight = RulerMetrics(scaler).height;
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
        Widget ruler(RulerLayer layer) =>
            RulerView(window: window, rate: state.frameRate, layer: layer);

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
                if (playheadX >= 0 && playheadX <= timeWidth)
                  Positioned(
                    left: playheadX - _Playhead.headSize / 2,
                    top: -playheadLead,
                    height: playheadLead + trackTop + metrics.height,
                    child: IgnorePointer(child: _Playhead(lead: playheadLead)),
                  ),
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

/// The red rule, rising [lead] px above the ruler, with a square head on
/// the ruler's top edge.
class _Playhead extends StatelessWidget {
  const _Playhead({required this.lead});

  final double lead;

  static const headSize = 10.0;
  static const _rule = 2.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: headSize,
    child: Stack(
      children: [
        Positioned(
          top: lead,
          left: 0,
          width: headSize,
          height: headSize,
          child: const ColoredBox(color: CutcapTokens.signal),
        ),
        const Positioned(
          top: 0,
          bottom: 0,
          left: (headSize - _rule) / 2,
          width: _rule,
          child: ColoredBox(color: CutcapTokens.signal),
        ),
      ],
    ),
  );
}
