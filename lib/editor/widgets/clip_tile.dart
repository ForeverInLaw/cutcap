import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cutcap_tokens.dart';
import '../editor_view_state.dart';
import '../timecode.dart';
import 'focus_ring.dart';
import 'timecode_text.dart';

/// Track metrics shared by the clip tiles, the add tile and the playhead.
/// The label rows grow with the system text size. [twoLineLabels] puts the
/// length under the name (phone), where tiles are too narrow for both.
@immutable
final class TrackMetrics {
  TrackMetrics(
    TextScaler scaler, {
    required this.filmHeight,
    this.twoLineLabels = false,
  }) : _line = (scaler.scale(_labelSize) * 1.3).ceilToDouble();

  static const _labelSize = 11.0;
  static const labelGap = 6.0;

  /// Narrower tiles drop the name and show the length alone.
  static const minNamedWidth = 70.0;

  final double _line;
  final double filmHeight;
  final bool twoLineLabels;

  double get labelHeight => twoLineLabels ? 2 * _line : _line;

  double get height => labelHeight + labelGap + filmHeight;
}

/// One clip: its name and length above a filmstrip. Selected clips carry a
/// 2 px ink frame, the just-edited clip a red base line, and a clip whose
/// file is gone a hatched field that says so.
///
/// The tile covers only the part of the clip inside the visible window, so
/// its label stays in view; [hiddenStart] (px of the clip left of the window)
/// and [filmWidth] (the whole clip) keep the filmstrip frames in place.
class ClipTile extends StatelessWidget {
  const ClipTile({
    required this.clip,
    required this.rate,
    required this.metrics,
    required this.onSelect,
    required this.hiddenStart,
    required this.filmWidth,
    super.key,
  });

  final ClipView clip;
  final FrameRate rate;
  final TrackMetrics metrics;
  final VoidCallback onSelect;
  final double hiddenStart;
  final double filmWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = CutcapTokens.of(context);
    final text = Theme.of(context).textTheme;
    final length = Timecode.full(clip.duration, rate);
    final motion = CutcapTokens.motion;
    final fade = motion.of(context, motion.short);

    return Semantics(
      button: true,
      selected: clip.isSelected,
      label: [
        clip.name,
        length,
        if (clip.isMissing) l10n.fileNotFound,
        if (clip.isJustEdited) l10n.justEdited,
      ].join(', '),
      excludeSemantics: true,
      child: FocusRing(
        child: InkWell(
          onTap: onSelect,
          mouseCursor: SystemMouseCursors.click,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: metrics.labelHeight,
                child: metrics.twoLineLabels
                    ? _StackedLabel(clip.name, length)
                    : Text.rich(
                        TextSpan(
                          text: clip.name,
                          children: [
                            TextSpan(
                              text: ' · $length',
                              style: TextStyle(
                                color: tokens.inkSecondary,
                                fontWeight: FontWeight.w400,
                                fontFeatures: TimecodeText.tabular,
                              ),
                            ),
                          ],
                        ),
                        style: text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(height: TrackMetrics.labelGap),
              SizedBox(
                height: metrics.filmHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (clip.isMissing)
                      const _MissingFilm()
                    else
                      _Filmstrip(
                        clip: clip,
                        frameColor: tokens.frame,
                        hiddenStart: hiddenStart,
                        filmWidth: filmWidth,
                      ),
                    _Marker(
                      visible: clip.isJustEdited,
                      duration: fade,
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 3,
                          width: double.infinity,
                          child: ColoredBox(color: CutcapTokens.signal),
                        ),
                      ),
                    ),
                    _Marker(
                      visible: clip.isSelected,
                      duration: fade,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.ink, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name over length, each on its own line; tiles narrower than
/// [TrackMetrics.minNamedWidth] keep the length line only.
class _StackedLabel extends StatelessWidget {
  const _StackedLabel(this.name, this.length);

  final String name;
  final String length;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final tokens = CutcapTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (constraints.maxWidth >= TrackMetrics.minNamedWidth)
            Text(
              name,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            length,
            style: style?.copyWith(
              color: tokens.inkSecondary,
              fontWeight: FontWeight.w400,
              fontFeatures: TimecodeText.tabular,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.visible,
    required this.duration,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: CutcapTokens.motion.curve,
      child: child,
    ),
  );
}

/// Frames across the clip, 1 px apart, each shaped like the source so
/// thumbnails show whole. Thumbnails are sampled evenly; solid frames stand
/// in until they load.
class _Filmstrip extends StatelessWidget {
  const _Filmstrip({
    required this.clip,
    required this.frameColor,
    required this.hiddenStart,
    required this.filmWidth,
  });

  final ClipView clip;
  final Color frameColor;
  final double hiddenStart;
  final double filmWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final thumbnails = clip.thumbnails;
      final frameWidth = constraints.maxHeight * clip.aspectRatio;
      final count = (filmWidth / frameWidth).ceil().clamp(1, 10000);
      final first = (hiddenStart / frameWidth).floor();
      final last = ((hiddenStart + constraints.maxWidth) / frameWidth).ceil();
      return ClipRect(
        child: Stack(
          children: [
            for (var i = first; i < last && i < count; i++)
              Positioned(
                left: i * frameWidth - hiddenStart,
                top: 0,
                bottom: 0,
                width: frameWidth - 1,
                child: thumbnails.isEmpty
                    ? ColoredBox(color: frameColor)
                    : Image(
                        image: thumbnails[i * thumbnails.length ~/ count],
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        gaplessPlayback: true,
                      ),
              ),
          ],
        ),
      );
    },
  );
}

/// The field of a clip whose source file is missing: ink hatching with the
/// problem named in words, or by icon alone when the clip is too narrow.
class _MissingFilm extends StatelessWidget {
  const _MissingFilm();

  @override
  Widget build(BuildContext context) {
    final tokens = CutcapTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(
      context,
    ).textTheme.labelLarge!.copyWith(fontSize: 12);
    const iconSize = 14.0;
    final space = CutcapTokens.space;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: tokens.ink)),
      child: CustomPaint(
        painter: _HatchPainter(tokens.ink),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final label = TextPainter(
              text: TextSpan(text: l10n.fileNotFound, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final labelWidth = label.width + iconSize + space.s + space.m * 2;
            label.dispose();
            final showLabel = labelWidth <= constraints.maxWidth - space.s;
            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.workspace,
                  border: Border.all(color: tokens.ink),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? space.m : space.xs,
                    vertical: space.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_off_sharp,
                        size: iconSize,
                        color: tokens.ink,
                      ),
                      if (showLabel) ...[
                        SizedBox(width: space.s),
                        Text(l10n.fileNotFound, style: style),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  static const _pitch = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // 45° lines rising to the right, one every [_pitch] px along the base.
    for (var x = -size.height; x < size.width; x += _pitch) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}
