/// A frame rate as an exact ratio, e.g. `FrameRate(30000, 1001)` for 29.97.
final class FrameRate {
  const FrameRate(this.numerator, this.denominator)
    : assert(numerator > 0 && denominator > 0);

  final int numerator;
  final int denominator;

  /// The rate as a decimal, for display (`29.97`).
  double get perSecond => numerator / denominator;
}

/// Formats sequence times with the frame within the second as the last field.
///
/// [full] is the headline form (`00:01:12.08`), used for the playhead, the
/// total and the ruler; [compact] is the short form for clip lengths and the
/// status line (`01:12.08`, with hours only from an hour on).
abstract final class Timecode {
  static String full(Duration time, FrameRate rate) {
    final parts = _Parts(time, rate);
    return '${_two(parts.hours)}:${_two(parts.minutes)}:'
        '${_two(parts.seconds)}.${_two(parts.frame)}';
  }

  static String compact(Duration time, FrameRate rate) {
    final parts = _Parts(time, rate);
    final rest =
        '${_two(parts.minutes)}:${_two(parts.seconds)}.${_two(parts.frame)}';
    return parts.hours > 0 ? '${parts.hours}:$rest' : rest;
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
