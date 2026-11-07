import 'frame_rate.dart';

/// Identifies a [Source] within an edit. Chosen by whoever probes the file.
extension type const SourceId(String value) {}

/// Frame size in pixels.
typedef Resolution = ({int width, int height});

/// A probed video file that clips are cut from.
final class Source {
  const Source({
    required this.id,
    required this.path,
    required this.duration,
    required this.resolution,
    required this.rotation,
    required this.frameRate,
    required this.hasAudio,
  }) : assert(duration > Duration.zero),
       assert(
         rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270,
       );

  final SourceId id;
  final String path;

  /// Playable length; no clip of this source reaches past it.
  final Duration duration;

  /// Coded frame size, before [rotation].
  final Resolution resolution;

  /// Clockwise turn in degrees (0, 90, 180 or 270) that shows the video
  /// upright.
  final int rotation;

  /// Nominal rate; its grid is what splits and trims snap to.
  final FrameRate frameRate;
  final bool hasAudio;
}
