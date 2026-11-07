import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../ruler.dart';

/// One update of a touch pan or pinch on the track, as the two intents the
/// track sends: scroll by [scroll], then zoom by [factor] around [anchor].
///
/// Scrolling first brings the time that was under the fingers to where they
/// are now; zooming around that point then keeps it there, so the track
/// follows the fingers the way a map does.
@immutable
final class TrackPinch {
  const TrackPinch._(this.scroll, this.factor, this.anchor);

  /// The step from fingers centred at [fromX] with scale [fromScale] to
  /// [toX] and [toScale] (px across a track [trackWidth] wide showing
  /// [window]; scale grows as the fingers spread).
  factory TrackPinch.between({
    required TimelineWindow window,
    required double trackWidth,
    required double fromX,
    required double toX,
    double fromScale = 1,
    double toScale = 1,
  }) {
    final moved = (fromX - toX) / trackWidth;
    return TrackPinch._(
      Duration(microseconds: (window.span.inMicroseconds * moved).round()),
      fromScale / toScale,
      (toX / trackWidth).clamp(0.0, 1.0),
    );
  }

  final Duration scroll;

  /// Below 1 zooms in.
  final double factor;

  /// Fraction across the track the zoom keeps in place.
  final double anchor;
}

/// How fast the zoomed track scrolls by itself while a drag (moving or
/// trimming a clip) holds the pointer near either end of it, so the drag
/// can reach past what is in view.
abstract final class EdgeScroll {
  /// Width of the band at each end, in px, where the track scrolls.
  static const zone = 48.0;

  /// Speed with the pointer at or past an end, in visible spans a second.
  static const maxRate = 1.5;

  /// Visible spans a second the track scrolls with the pointer at [x] on a
  /// track [trackWidth] wide: negative back towards the start, zero away
  /// from the ends, rising linearly to [maxRate] at an end. The bands
  /// narrow to a quarter of a short track each.
  static double rate(double x, {required double trackWidth}) {
    final band = math.min(zone, trackWidth / 4);
    if (band <= 0) return 0;
    final pastStart = band - x;
    final pastEnd = x - (trackWidth - band);
    if (pastStart > 0) return -maxRate * math.min(1, pastStart / band);
    if (pastEnd > 0) return maxRate * math.min(1, pastEnd / band);
    return 0;
  }
}
