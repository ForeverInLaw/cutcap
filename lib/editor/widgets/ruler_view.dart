import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/cutcap_tokens.dart';
import '../ruler.dart';
import '../../domain/frame_rate.dart';
import '../timecode.dart';
import 'timecode_text.dart';

/// Vertical layout of the ruler, scaled with the system text size: the
/// playhead head on top, the row of guide words and labels under it, ticks
/// along the bottom.
///
/// [minHeight] stretches the ruler (the space goes between labels and
/// ticks) so it stays a comfortable touch target for scrubbing.
@immutable
final class RulerMetrics {
  RulerMetrics(TextScaler scaler, {this.minHeight = 0})
    : labelLine = (scaler.scale(_labelSize) * 1.25).ceilToDouble();

  final double minHeight;

  static const _labelSize = 12.0;

  /// Room for the playhead head above the labels.
  static const labelTop = 12.0;
  static const majorTick = 14.0;
  static const minorTick = 5.0;
  static const _labelGap = 4.0;

  final double labelLine;

  double get height =>
      math.max(minHeight, labelTop + labelLine + _labelGap + majorTick);

  /// The band labels occupy, cleared to the workspace behind each label so
  /// the playhead rule visibly stops above a time and resumes below it.
  double get knockoutTop => labelTop - 2;
  double get knockoutBottom => labelTop + labelLine + _labelGap;
}

enum RulerLayer {
  /// Ticks, drawn under the playhead.
  ticks,

  /// Guide words and tick labels on paper knockouts, drawn over the
  /// playhead so the red rule never runs through a time.
  labels,
}

/// One layer of the time ruler. The guide words name the first and last
/// time in view; labelled major ticks sit between them.
class RulerView extends StatelessWidget {
  const RulerView({
    required this.window,
    required this.rate,
    required this.layer,
    required this.metrics,
    super.key,
  });

  final TimelineWindow window;
  final FrameRate rate;
  final RulerLayer layer;
  final RulerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = CutcapTokens.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return CustomPaint(
      size: Size.infinite,
      painter: switch (layer) {
        RulerLayer.ticks => _TickPainter(window, rate, tokens.ink),
        RulerLayer.labels => _LabelPainter(
          window: window,
          rate: rate,
          paper: tokens.workspace,
          metrics: metrics,
          guideStyle: text.labelMedium!.copyWith(
            color: tokens.ink,
            fontFeatures: TimecodeText.tabular,
          ),
          labelStyle: text.labelMedium!.copyWith(
            color: tokens.inkSecondary,
            fontWeight: FontWeight.w400,
            fontFeatures: TimecodeText.tabular,
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        ),
      },
    );
  }
}

/// x of [time] on a ruler [width] wide, kept inside the canvas.
double _xOf(TimelineWindow window, Duration time, double width) =>
    (window.fractionOf(time) * width).clamp(0.5, width - 0.5);

class _TickPainter extends CustomPainter {
  const _TickPainter(this.window, this.rate, this.ink);

  final TimelineWindow window;
  final FrameRate rate;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.span <= Duration.zero) return;
    final paint = Paint()
      ..color = ink
      ..strokeWidth = 1;
    void tick(double x, double length) => canvas.drawLine(
      Offset(x, size.height - length),
      Offset(x, size.height),
      paint,
    );

    tick(0.5, RulerMetrics.majorTick);
    for (final mark in Ruler.ticks(window, width: size.width, rate: rate)) {
      tick(
        _xOf(window, mark.time, size.width),
        mark.major ? RulerMetrics.majorTick : RulerMetrics.minorTick,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.window != window || old.rate != rate || old.ink != ink;
}

class _LabelPainter extends CustomPainter {
  _LabelPainter({
    required this.window,
    required this.rate,
    required this.paper,
    required this.metrics,
    required this.guideStyle,
    required this.labelStyle,
    required this.textDirection,
    required this.textScaler,
  });

  final TimelineWindow window;
  final FrameRate rate;
  final Color paper;
  final RulerMetrics metrics;
  final TextStyle guideStyle;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  static const _inset = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.span <= Duration.zero) return;
    final top = RulerMetrics.labelTop;

    for (final mark in Ruler.ticks(window, width: size.width, rate: rate)) {
      if (!mark.labelled) continue;
      final x = _xOf(window, mark.time, size.width) + _inset;
      _label(canvas, Timecode.full(mark.time, rate), labelStyle, x, top);
    }
    _label(canvas, Timecode.full(window.start, rate), guideStyle, 0, top);
    final end = _layout(Timecode.full(window.end, rate), guideStyle);
    _paintOnPaper(canvas, end, Offset(size.width - end.width, top));
  }

  void _label(
    Canvas canvas,
    String value,
    TextStyle style,
    double x,
    double y,
  ) => _paintOnPaper(canvas, _layout(value, style), Offset(x, y));

  /// Paints [text] on a knockout that clears whatever runs beneath, from
  /// just under the playhead head down to the ticks.
  void _paintOnPaper(Canvas canvas, TextPainter text, Offset at) {
    canvas.drawRect(
      Rect.fromLTRB(
        at.dx - 4,
        metrics.knockoutTop,
        at.dx + text.width + 4,
        metrics.knockoutBottom,
      ),
      Paint()..color = paper,
    );
    text
      ..paint(canvas, at + Offset(0, (metrics.labelLine - text.height) / 2))
      ..dispose();
  }

  TextPainter _layout(String value, TextStyle style) => TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  bool shouldRepaint(_LabelPainter old) =>
      old.window != window ||
      old.rate != rate ||
      old.paper != paper ||
      old.metrics.labelLine != metrics.labelLine ||
      old.guideStyle != guideStyle ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
