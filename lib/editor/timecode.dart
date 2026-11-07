/// A frame rate as an exact ratio, e.g. `FrameRate(30000, 1001)` for 29.97.
final class FrameRate {
  const FrameRate(this.numerator, this.denominator)
    : assert(numerator > 0 && denominator > 0);

  final int numerator;
  final int denominator;

  /// The rate as a decimal, for display (`29.97`).
  double get perSecond => numerator / denominator;

  /// One frame, truncated to whole microseconds.
  Duration get frameDuration => Duration(
    microseconds: denominator * Duration.microsecondsPerSecond ~/ numerator,
  );

  @override
  bool operator ==(Object other) =>
      other is FrameRate &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

/// Formats sequence times as `HH:MM:SS.FF`, the frame within the second
/// last. The one timecode form of the screen: headline, total, ruler, clip
/// lengths and status line all use it.
abstract final class Timecode {
  static String full(Duration time, FrameRate rate) {
    final parts = _Parts(time, rate);
    return '${_two(parts.hours)}:${_two(parts.minutes)}:'
        '${_two(parts.seconds)}.${_two(parts.frame)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

final class _Parts {
  _Parts(Duration time, FrameRate rate)
    : assert(!time.isNegative),
      _wholeSeconds = time.inMicroseconds ~/ Duration.microsecondsPerSecond,
      frame = _frameInSecond(
        time.inMicroseconds % Duration.microsecondsPerSecond,
        rate,
      );

  final int _wholeSeconds;
  final int frame;

  int get hours => _wholeSeconds ~/ 3600;
  int get minutes => _wholeSeconds ~/ 60 % 60;
  int get seconds => _wholeSeconds % 60;

  /// Frame start times are truncated to whole microseconds, so a time counts
  /// as frame k once it is within 1 µs of k's exact start.
  static int _frameInSecond(int microseconds, FrameRate rate) {
    final scaled = microseconds * rate.numerator + rate.numerator - 1;
    return scaled ~/ (rate.denominator * Duration.microsecondsPerSecond);
  }
}
