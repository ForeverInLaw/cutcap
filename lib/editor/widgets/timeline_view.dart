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
class TimelineView extends StatelessWidget {
  const TimelineView({
    required this.state,
    required this.actions,
    required this.compact,
    super.key,
  });

  final EditorViewState state;
  final EditorActions actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final space = CutcapTokens.space;
    final metrics = compact ? TrackMetrics.phone : TrackMetrics.desktop;
    final rulerHeight = compact ? 36.0 : 40.0;
    final rulerGap = compact ? space.s : 10.0;
    final addWidth = compact ? 48.0 : 56.0;
    final trackTop = rulerHeight + rulerGap;
    final filmTop = trackTop + metrics.labelHeight + metrics.labelGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeWidth = constraints.maxWidth - addWidth - space.xs;
        final window = state.visibleWindow;
        double xOf(Duration time) => window.fractionOf(time) * timeWidth;
        final playheadX = xOf(state.position);

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
                    child: RulerView(window: window, rate: state.frameRate),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: trackTop,
                  width: timeWidth,
                  height: metrics.height,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        for (final (clip, start) in _placed(state.clips))
                          if (start < window.end &&
                              start + clip.duration > window.start)
                            Positioned(
                              key: ValueKey(clip.id),
                              left: xOf(start),
                              top: 0,
                              bottom: 0,
                              width:
                                  (xOf(start + clip.duration) -
                                          xOf(start) -
                                          space.xs)
                                      .clamp(1.0, double.infinity),
                              child: ClipTile(
                                clip: clip,
                                rate: state.frameRate,
                                metrics: metrics,
                                onSelect: () => actions.onSelectClip(clip.id),
                              ),
                            ),
                      ],
                    ),
                  ),
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
                    top: 0,
                    height: trackTop + metrics.height,
                    child: const IgnorePointer(child: _Playhead()),
                  ),
              ],
            ),
          ),
        );
      },
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

/// The red rule with a square head, centred on the playhead time.
class _Playhead extends StatelessWidget {
  const _Playhead();

  static const headSize = 10.0;
  static const _rule = 2.0;

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: headSize,
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          width: headSize,
          height: headSize,
          child: ColoredBox(color: CutcapTokens.signal),
        ),
        Positioned(
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
