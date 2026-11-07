import 'package:flutter/material.dart';

/// A time display. Digits sit in fixed tabular cells, so a running
/// timecode changes in place instead of jittering sideways.
class TimecodeText extends StatelessWidget {
  const TimecodeText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  /// Font features for any time shown inside other text.
  static const tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    style: (style ?? const TextStyle()).copyWith(fontFeatures: tabular),
  );
}
