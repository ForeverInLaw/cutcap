import 'package:flutter/material.dart';

import '../../theme/cutcap_tokens.dart';

/// Draws a 2 px ink ring, 2 px clear of the edge, around [child] while a
/// control inside it has keyboard focus. Pointer focus draws nothing.
///
/// The ring takes the ambient theme's `onSurface`, so it reads paper on the
/// black top bar and ink on the workspace.
class FocusRing extends StatefulWidget {
  const FocusRing({required this.child, super.key});

  final Widget child;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final showRing =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: CustomPaint(
        foregroundPainter: showRing
            ? _RingPainter(Theme.of(context).colorScheme.onSurface)
            : null,
        child: widget.child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color);

  final Color color;

  static const _gap = 2.0;
  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(_gap + _stroke / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(CutcapTokens.radius.control + _gap),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.color != color;
}
