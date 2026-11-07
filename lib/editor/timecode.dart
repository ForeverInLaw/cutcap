import '../domain/frame_rate.dart';

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
      frame = rate.frameAt(
        Duration(
          microseconds: time.inMicroseconds % Duration.microsecondsPerSecond,
        ),
      );

  final int _wholeSeconds;
  final int frame;

  int get hours => _wholeSeconds ~/ 3600;
  int get minutes => _wholeSeconds ~/ 60 % 60;
  int get seconds => _wholeSeconds % 60;
}
