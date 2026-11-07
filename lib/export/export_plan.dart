import '../domain/edit_list.dart';
import '../domain/frame_rate.dart';
import '../domain/source.dart';

/// Audio sample rate of every export.
const exportSampleRate = 48000;

/// What an export produces, worked out from an [EditList] by the output rules
/// of the spec and ADR 0002: the first clip's upright size and rate, its
/// bitrate, and every clip snapped to whole output frames with the audio
/// samples that match them.
final class ExportPlan {
  const ExportPlan._({
    required this.size,
    required this.frameRate,
    required this.videoBitRate,
    required this.clips,
  });

  /// The plan for [editList] without the clips whose source is in
  /// [missingSources], or null when no clip is left.
  static ExportPlan? of(
    EditList editList, {
    Set<SourceId> missingSources = const {},
  }) {
    final present = [
      for (final clip in editList.clips)
        if (!missingSources.contains(clip.sourceId)) clip,
    ];
    if (present.isEmpty) return null;

    final first = editList.sourceOf(present.first);
    final size = _uprightSize(first);
    final rate = _outputRate(first);
    final clips = <PlannedClip>[];
    var framesBefore = 0;
    for (final clip in present) {
      final source = editList.sourceOf(clip);
      final frames = _frameCount(clip.duration, rate);
      clips.add(
        PlannedClip._(
          path: source.path,
          seek: source.frameRate.seekTarget(clip.inPoint),
          duration: clip.duration,
          frames: frames,
          audioSamples:
              _samplesIn(framesBefore + frames, rate) -
              _samplesIn(framesBefore, rate),
          hasAudio: source.hasAudio,
        ),
      );
      framesBefore += frames;
    }
    return ExportPlan._(
      size: size,
      frameRate: rate,
      videoBitRate: _videoBitRate(first, size, rate),
      clips: List.unmodifiable(clips),
    );
  }

  /// Output frame size: the first clip's display size.
  final Resolution size;

  /// Output frame rate.
  final FrameRate frameRate;

  /// Target video bitrate in bits per second.
  final int videoBitRate;

  /// The clips to export, in sequence order.
  final List<PlannedClip> clips;

  /// Length of the output.
  Duration get duration =>
      frameRate.frameStart(clips.fold(0, (total, clip) => total + clip.frames));
}

/// One clip of an [ExportPlan].
final class PlannedClip {
  const PlannedClip._({
    required this.path,
    required this.seek,
    required this.duration,
    required this.frames,
    required this.audioSamples,
    required this.hasAudio,
  });

  /// Source file.
  final String path;

  /// Where to seek the source so decoding starts at the clip's first frame.
  final Duration seek;

  /// Source time the clip spans.
  final Duration duration;

  /// Output frames the clip fills.
  final int frames;

  /// Output audio samples (at [exportSampleRate]) the clip fills; silence
  /// when the source has no audio.
  final int audioSamples;

  final bool hasAudio;
}

/// [duration] in whole frames at [rate], rounded to the nearest.
int _frameCount(Duration duration, FrameRate rate) => _roundedDivision(
  duration.inMicroseconds * rate.numerator,
  rate.denominator * Duration.microsecondsPerSecond,
);

/// Audio samples that play during the first [frames] output frames, rounded
/// to the nearest. Counting from the start keeps rates like 29.97 from
/// drifting clip by clip.
int _samplesIn(int frames, FrameRate rate) => _roundedDivision(
  frames * exportSampleRate * rate.denominator,
  rate.numerator,
);

/// `a / b` rounded half up, for non-negative `a` and positive `b`.
int _roundedDivision(int a, int b) => (2 * a + b) ~/ (2 * b);

/// The frame size of [source] as shown, after its rotation.
Resolution _uprightSize(Source source) {
  final (:width, :height) = source.resolution;
  return source.rotation % 180 == 0
      ? (width: width, height: height)
      : (width: height, height: width);
}

/// The rate to export a sequence starting with [source] at: its nominal
/// rate, or for a variable-rate source (average off by more than 0.1 %) its
/// average rounded to the nearest standard rate.
FrameRate _outputRate(Source source) {
  final nominal = source.frameRate;
  final average = source.averageFrameRate?.perSecond;
  if (average == null ||
      (average - nominal.perSecond).abs() <= nominal.perSecond * 0.001) {
    return nominal;
  }
  final nearest = _standardRates.reduce(
    (best, rate) =>
        (rate - average).abs() < (best - average).abs() ? rate : best,
  );
  return FrameRate(nearest, 1);
}

const _standardRates = [24, 25, 30, 50, 60];

/// The first clip's video bitrate, or an estimate of 0.1 bit per pixel when
/// it is unknown, kept within 1 to 50 Mb/s.
int _videoBitRate(Source source, Resolution size, FrameRate rate) {
  final bitRate =
      source.videoBitRate ??
      size.width * size.height * rate.numerator ~/ (10 * rate.denominator);
  return bitRate.clamp(1000000, 50000000);
}
