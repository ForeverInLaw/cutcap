/// A frame rate as an exact ratio, e.g. `FrameRate(30000, 1001)` for 29.97.
///
/// It also defines the frame grid of a source: frame k starts at
/// `k · denominator / numerator` seconds, truncated to whole microseconds.
final class FrameRate {
  const FrameRate(this.numerator, this.denominator)
    : assert(numerator > 0 && denominator > 0);

  final int numerator;
  final int denominator;

  /// The rate as a decimal, for display (`29.97`).
  double get perSecond => numerator / denominator;

  /// One frame, truncated to whole microseconds.
  Duration get frameDuration => Duration(microseconds: _scale ~/ numerator);

  /// Start time of [frame] on the grid.
  Duration frameStart(int frame) =>
      Duration(microseconds: frame * _scale ~/ numerator);

  /// Index of the frame showing at [time]: the last one starting at or
  /// before it. Because frame starts are truncated, a time counts as frame k
  /// once it reaches k's truncated start.
  int frameAt(Duration time) =>
      ((time.inMicroseconds + 1) * numerator - 1) ~/ _scale;

  /// The frame start closest to [time], which must not be negative; a time
  /// halfway between two starts goes to the earlier one.
  Duration nearestFrameStart(Duration time) {
    final frame = frameAt(time);
    final before = frameStart(frame);
    final after = frameStart(frame + 1);
    return time - before <= after - time ? before : after;
  }

  /// The time to seek a player or `ffmpeg -ss` to so that it shows the frame
  /// under [time] (ADR 0002): that frame's start minus half a frame, never
  /// negative. Decoders show the first frame whose pts is at or after the
  /// target, so this lands on the frame whichever way pts were rounded.
  Duration seekTarget(Duration time) {
    final start = frameStart(frameAt(time)).inMicroseconds;
    final halfFrame = _scale ~/ (2 * numerator);
    return Duration(microseconds: start < halfFrame ? 0 : start - halfFrame);
  }

  /// Microseconds per second times [denominator]: one frame is
  /// `_scale / numerator` µs.
  int get _scale => denominator * Duration.microsecondsPerSecond;

  @override
  bool operator ==(Object other) =>
      other is FrameRate &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}
