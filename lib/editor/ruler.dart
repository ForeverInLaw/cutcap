import '../domain/frame_rate.dart';

/// The span of sequence time the track currently shows.
final class TimelineWindow {
  const TimelineWindow(this.start, this.end);

  final Duration start;
  final Duration end;

  Duration get span => end - start;

  /// Where [time] falls across the window: 0 at [start], 1 at [end].
  double fractionOf(Duration time) =>
      (time - start).inMicroseconds / span.inMicroseconds;

  /// The time at [fraction] across the window, clamped to the window.
  Duration timeAt(double fraction) => Duration(
    microseconds:
        start.inMicroseconds +
        (span.inMicroseconds * fraction.clamp(0.0, 1.0)).round(),
  );

  @override
  bool operator ==(Object other) =>
      other is TimelineWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// One mark on the ruler.
typedef RulerTick = ({Duration time, bool major, bool labelled});

/// Picks tick steps for the ruler so marks stay legible at any zoom: whole
/// frames when zoomed in, round seconds and minutes when zoomed out.
abstract final class Ruler {
  /// Minimum distance between labelled (major) ticks.
  static const double majorSpacing = 120;

  /// Room one timecode label takes, gap included. Labels start at their
  /// tick and run right, so they keep this much clear of the opening guide
  /// word and twice this of the closing one.
  static const double labelRoom = 90;

  /// Minimum distance between any two ticks.
  static const double minorSpacing = 8;

  static const List<int> _frameSteps = [1, 2, 5, 10];
  static const List<int> _secondSteps = [
    1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, //
  ];

  static List<RulerTick> ticks(
    TimelineWindow window, {
    required double width,
    required FrameRate rate,
  }) {
    final steps = [
      for (final frames in _frameSteps)
        if (frames * rate.denominator < rate.numerator)
          _Step(frames * rate.denominator, rate.numerator),
      for (final seconds in _secondSteps) _Step(seconds, 1),
    ];
    final pxPerSecond = width / (window.span.inMicroseconds / 1e6);
    bool fits(_Step step, double spacing) =>
        step.seconds * pxPerSecond >= spacing;

    final major = steps.firstWhere(
      (step) => fits(step, majorSpacing),
      orElse: () => steps.last,
    );
    final minor = steps.firstWhere(
      (step) => major.isMultipleOf(step) && fits(step, minorSpacing),
    );

    final ticks = <RulerTick>[];
    for (var i = minor.indexAfter(window.start); ; i++) {
      final time = minor.at(i);
      if (time > window.end) break;
      final isMajor = minor.isOnGridOf(major, i);
      final x = window.fractionOf(time) * width;
      ticks.add((
        time: time,
        major: isMajor,
        labelled: isMajor && x >= labelRoom && x <= width - 2 * labelRoom,
      ));
    }
    return ticks;
  }
}

/// A tick step of exactly [numerator] / [denominator] seconds.
final class _Step {
  const _Step(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  static const _us = Duration.microsecondsPerSecond;

  double get seconds => numerator / denominator;

  /// The [index]th multiple of this step, truncated to whole microseconds
  /// the way frame start times are.
  Duration at(int index) =>
      Duration(microseconds: index * numerator * _us ~/ denominator);

  /// The index of the first multiple strictly after [time].
  int indexAfter(Duration time) =>
      time.inMicroseconds * denominator ~/ (numerator * _us) + 1;

  bool isMultipleOf(_Step other) =>
      (numerator * other.denominator) % (other.numerator * denominator) == 0;

  /// Whether this step's [index]th multiple is also a multiple of [coarser].
  bool isOnGridOf(_Step coarser, int index) =>
      (index * numerator * coarser.denominator) %
          (coarser.numerator * denominator) ==
      0;
}
