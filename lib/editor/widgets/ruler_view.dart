import 'package:flutter/material.dart';

import '../../theme/cutcap_tokens.dart';
import '../ruler.dart';
import '../timecode.dart';
import 'timecode_text.dart';

/// The time ruler: guide words naming the first and last time in view,
/// labelled major ticks between them, and minor ticks along the bottom.
class RulerView extends StatelessWidget {
  const RulerView({required this.window, required this.rate, super.key});

  final TimelineWindow window;
  final FrameRate rate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = CutcapTokens.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _RulerPainter(
        window: window,
        rate: rate,
        ink: tokens.ink,
        guideStyle: text.labelMedium!.copyWith(
          color: tokens.ink,
          fontFeatures: TimecodeText.tabular,
        ),
        labelStyle: text.labelSmall!.copyWith(
          color: tokens.inkSecondary,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          fontFeatures: TimecodeText.tabular,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.window,
    required this.rate,
    required this.ink,
    required this.guideStyle,
    required this.labelStyle,
    required this.textDirection,
    required this.textScaler,
  });

  final TimelineWindow window;
  final FrameRate rate;
  final Color ink;
  final TextStyle guideStyle;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  static const _minorTick = 5.0;
  static const _majorTick = 14.0;
  static const _textInset = 3.0;
  static const _textTop = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.span <= Duration.zero) return;
    final tick = Paint()
      ..color = ink
      ..strokeWidth = 1;

    for (final mark in Ruler.ticks(window, width: size.width, rate: rate)) {
      // Keep the last tick inside the canvas.
      final x = (window.fractionOf(mark.time) * size.width).clamp(
        0.5,
        size.width - 0.5,
      );
      final length = mark.major ? _majorTick : _minorTick;
      canvas.drawLine(
        Offset(x, size.height - length),
        Offset(x, size.height),
        tick,
      );
      if (mark.labelled) {
        _text(Timecode.full(mark.time, rate), labelStyle)
          ..paint(canvas, Offset(x + _textInset, _textTop + 1))
          ..dispose();
      }
    }
    canvas.drawLine(
      Offset(0.5, size.height - _majorTick),
      Offset(0.5, size.height),
      tick,
    );

    _text(Timecode.full(window.start, rate), guideStyle)
      ..paint(canvas, const Offset(_textInset, _textTop))
      ..dispose();
    final end = _text(Timecode.full(window.end, rate), guideStyle);
    end
      ..paint(canvas, Offset(size.width - end.width, _textTop))
      ..dispose();
  }

  TextPainter _text(String value, TextStyle style) => TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.window != window ||
      old.rate != rate ||
      old.ink != ink ||
      old.guideStyle != guideStyle ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
