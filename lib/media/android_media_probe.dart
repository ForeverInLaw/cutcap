import 'package:flutter/services.dart';

import '../domain/editor_session.dart';
import '../platform/android_channels.dart';
import 'media_probe.dart';

/// [MediaProbe] on Android: the Kotlin side reads the file with
/// `MediaExtractor` and `MediaMetadataRetriever` and reports raw facts; [parse]
/// turns them into a [Source] with the same fields the ffprobe probe fills.
///
/// Android reports no exact rational frame rate, so the nominal rate is
/// recovered from the presentation times of the first frames.
final class AndroidMediaProbe implements MediaProbe {
  const AndroidMediaProbe();

  @override
  Future<Source> probe(String path) async {
    final Map<Object?, Object?>? report;
    try {
      report = await AndroidChannels.media.invokeMapMethod<Object?, Object?>(
        'probe',
        {'path': path},
      );
    } on PlatformException catch (error) {
      // The Kotlin probe puts the file's name, when it got that far, in
      // the details.
      throw UndecodableMedia(
        path,
        '${error.code}: ${error.message}',
        displayName: _name(error.details),
      );
    }
    if (report == null) throw UndecodableMedia(path, 'no report');
    return parse(report, path: path);
  }

  /// The [Source] described by the Kotlin probe's [report] for the video at
  /// [path] (also its id):
  ///
  /// ```
  /// {name, frameCount, durationUs, bitRate,      // container, all nullable
  ///  video: {mime, decodable, width, height, rotation, durationUs, bitRate,
  ///          frameRate, sampleTimesUs: [first frames, presentation order]},
  ///  audio: [{mime, bitRate}]}
  /// ```
  ///
  /// Throws [UndecodableMedia] when there is no video track this device can
  /// decode, or it has no size or no positive length.
  static Source parse(Map<Object?, Object?> report, {required String path}) {
    final name = _name(report['name']);
    Never fail(String reason) =>
        throw UndecodableMedia(path, reason, displayName: name);

    final video = switch (report['video']) {
      final Map<Object?, Object?> video => video,
      _ => fail('no video track'),
    };
    if (video['decodable'] != true) fail('no decoder for ${video['mime']}');
    final (width, height) = switch (video) {
      {'width': final int width, 'height': final int height}
          when width > 0 && height > 0 =>
        (width, height),
      _ => fail('no frame size'),
    };
    final duration =
        _micros(video['durationUs']) ?? _micros(report['durationUs']);
    if (duration == null || duration <= Duration.zero) fail('no duration');
    final times = switch (video['sampleTimesUs']) {
      final List<Object?> times => times.whereType<int>().toList(),
      _ => const <int>[],
    };
    final rate =
        nominalRate(times) ??
        _approximate(video['frameRate']) ??
        fail('no frame rate');
    final audio = switch (report['audio']) {
      final List<Object?> tracks => tracks.whereType<Map<Object?, Object?>>(),
      _ => const <Map<Object?, Object?>>[],
    };
    return Source(
      id: SourceId(path),
      path: path,
      displayName: name,
      duration: duration,
      resolution: (width: width, height: height),
      rotation: switch (video['rotation']) {
        final int degrees => ((degrees / 90).round() * 90) % 360,
        _ => 0,
      },
      frameRate: rate,
      hasAudio: audio.isNotEmpty,
      averageFrameRate: _average(report['frameCount'], duration),
      videoBitRate: _videoBitRate(video, audio, report),
    );
  }

  /// The video track's own bitrate, else the container's minus its audio;
  /// null when neither is known.
  static int? _videoBitRate(
    Map<Object?, Object?> video,
    Iterable<Map<Object?, Object?>> audio,
    Map<Object?, Object?> container,
  ) {
    int? bitRate(Map<Object?, Object?> json) => switch (json['bitRate']) {
      final int value when value > 0 => value,
      _ => null,
    };
    final own = bitRate(video);
    if (own != null) return own;
    final total = bitRate(container);
    if (total == null) return null;
    final rest =
        total - audio.map(bitRate).nonNulls.fold<int>(0, (a, b) => a + b);
    return rest > 0 ? rest : null;
  }

  /// The nominal rate of frames shown at [times] (µs, any order): the
  /// common interval between neighbours, matched to a standard rate when
  /// one is within [_standardTolerance]; null for fewer than two frames.
  static FrameRate? nominalRate(List<int> times) {
    final sorted = times.toSet().toList()..sort();
    if (sorted.length < 2) return null;
    final intervals = [
      for (var i = 1; i < sorted.length; i++) sorted[i] - sorted[i - 1],
    ]..sort();
    final median = intervals[intervals.length ~/ 2];
    // Averaging the intervals near the median undoes the truncation of
    // each time to whole microseconds (29.97 fps: 33366, 33367, ...) and
    // camera jitter, while dropped frames and rate changes stay out.
    final typical = intervals.where(
      (interval) => (interval - median).abs() <= median * 0.1,
    );
    final perSecond =
        Duration.microsecondsPerSecond *
        typical.length /
        typical.fold<int>(0, (sum, interval) => sum + interval);
    return _closestStandard(perSecond) ?? _rounded(perSecond);
  }

  /// Rates cameras, screen recorders and encoders produce.
  static const _standardRates = [
    FrameRate(8, 1),
    FrameRate(10, 1),
    FrameRate(12, 1),
    FrameRate(15, 1),
    FrameRate(20, 1),
    FrameRate(24000, 1001),
    FrameRate(24, 1),
    FrameRate(25, 1),
    FrameRate(30000, 1001),
    FrameRate(30, 1),
    FrameRate(48, 1),
    FrameRate(50, 1),
    FrameRate(60000, 1001),
    FrameRate(60, 1),
    FrameRate(90, 1),
    FrameRate(100, 1),
    FrameRate(120000, 1001),
    FrameRate(120, 1),
    FrameRate(144, 1),
    FrameRate(240, 1),
  ];

  /// How far a measured rate may stray from a standard one and still be
  /// taken as it: camera timestamps jitter by about a percent.
  static const _standardTolerance = 0.02;

  static FrameRate? _closestStandard(double perSecond) {
    FrameRate? best;
    var bestError = _standardTolerance;
    for (final rate in _standardRates) {
      final error = (rate.perSecond - perSecond).abs() / rate.perSecond;
      if (error <= bestError) {
        best = rate;
        bestError = error;
      }
    }
    return best;
  }

  /// [perSecond] to the millihertz, as an exact ratio.
  static FrameRate? _rounded(double perSecond) {
    final millihertz = (perSecond * 1000).round();
    return millihertz > 0 ? _reduced(millihertz, 1000) : null;
  }

  /// A rate the track header gives as a plain number (`frame-rate`).
  static FrameRate? _approximate(Object? value) => switch (value) {
    final num rate when rate > 0 =>
      _closestStandard(rate.toDouble()) ?? _rounded(rate.toDouble()),
    _ => null,
  };

  /// [frameCount] frames over [duration], as ffprobe's `avg_frame_rate`.
  static FrameRate? _average(Object? frameCount, Duration duration) =>
      switch (frameCount) {
        final int count when count > 0 => _reduced(
          count * Duration.microsecondsPerSecond,
          duration.inMicroseconds,
        ),
        _ => null,
      };

  static FrameRate _reduced(int numerator, int denominator) {
    final divisor = numerator.gcd(denominator);
    return FrameRate(numerator ~/ divisor, denominator ~/ divisor);
  }

  static String? _name(Object? value) => switch (value) {
    final String name when name.isNotEmpty => name,
    _ => null,
  };

  static Duration? _micros(Object? value) => switch (value) {
    final int us => Duration(microseconds: us),
    _ => null,
  };
}
