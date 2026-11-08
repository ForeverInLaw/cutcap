import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'timecode_text.dart';

/// Where the headline timecode sits inside a [PositionReadout], so other
/// parts of the screen can line up with it: controls stand on its baseline
/// and the playhead rule is tied to it.
@immutable
final class ReadoutGeometry {
  const ReadoutGeometry({
    required this.scale,
    required this.timeWidth,
    required this.baselineDrop,
    required this.height,
  });

  /// Shrink applied when the readout does not fit its width (narrow windows,
  /// large system font sizes); 1 otherwise.
  final double scale;

  /// Width of the playhead time, from the readout's left edge.
  final double timeWidth;

  /// Distance from the readout's bottom edge up to the time's baseline.
  final double baselineDrop;

  /// Height of the readout.
  final double height;
}

/// The playhead time set as the screen's headline, followed by the grey
/// sequence total on the same baseline: 80 px on desktop, 44 px when
/// [compact] (phone). Shrinks as a whole to fit its width.
class PositionReadout extends StatelessWidget {
  const PositionReadout({
    required this.state,
    required this.compact,
    required this.geometry,
    super.key,
  });

  final EditorViewState state;
  final bool compact;
  final ReadoutGeometry geometry;

  static const _desktopGap = 12.0;
  static const _phoneGap = 8.0;

  /// The time's and the total's styles. Ink-muted is only for the full
  /// 28 px desktop total: once the readout is [shrunk], the total takes
  /// ink-secondary like other small text (DESIGN.md).
  static (TextStyle, TextStyle) _styles(
    BuildContext context,
    bool compact, {
    bool shrunk = false,
  }) {
    final text = Theme.of(context).textTheme;
    final tokens = CutcapTokens.of(context);
    final time = (compact ? text.displaySmall : text.displayLarge)!;
    // Line height 1 so the headline alone sets the baseline drop.
    final total = compact
        ? text.bodyLarge!.copyWith(color: tokens.inkSecondary, height: 1)
        : text.headlineMedium!.copyWith(
            color: shrunk ? tokens.inkSecondary : tokens.inkMuted,
          );
    return (
      time.copyWith(fontFeatures: TimecodeText.tabular),
      total.copyWith(fontFeatures: TimecodeText.tabular),
    );
  }

  static (String, String) _texts(EditorViewState state) => (
    Timecode.full(state.position, state.frameRate),
    '/ ${Timecode.full(state.duration, state.frameRate)}',
  );

  /// Lays the readout out for [maxWidth] without building it.
  static ReadoutGeometry measure(
    BuildContext context, {
    required EditorViewState state,
    required bool compact,
    required double maxWidth,
  }) {
    final (timeStyle, totalStyle) = _styles(context, compact);
    final (time, total) = _texts(state);
    TextPainter layout(String value, TextStyle style) => TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final timePainter = layout(time, timeStyle);
    final totalPainter = layout(total, totalStyle);
    final width =
        timePainter.width +
        (compact ? _phoneGap : _desktopGap) +
        totalPainter.width;
    final scale = width > maxWidth ? maxWidth / width : 1.0;
    final geometry = ReadoutGeometry(
      scale: scale,
      timeWidth: timePainter.width * scale,
      baselineDrop:
          (timePainter.height -
              timePainter.computeDistanceToActualBaseline(
                TextBaseline.alphabetic,
              )) *
          scale,
      height: timePainter.height * scale,
    );
    timePainter.dispose();
    totalPainter.dispose();
    return geometry;
  }

  @override
  Widget build(BuildContext context) {
    final (timeStyle, totalStyle) = _styles(
      context,
      compact,
      shrunk: geometry.scale < 1,
    );
    final (time, total) = _texts(state);
    TextStyle scaled(TextStyle style) => geometry.scale == 1
        ? style
        : style.copyWith(
            fontSize: style.fontSize! * geometry.scale,
            letterSpacing: (style.letterSpacing ?? 0) * geometry.scale,
          );

    return Semantics(
      label: AppLocalizations.of(context).position,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          TimecodeText(time, style: scaled(timeStyle)),
          SizedBox(width: (compact ? _phoneGap : _desktopGap) * geometry.scale),
          Flexible(child: TimecodeText(total, style: scaled(totalStyle))),
        ],
      ),
    );
  }
}
