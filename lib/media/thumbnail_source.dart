/// One frame to render: the frame a decoder shows after an exact seek to
/// [seek] (ADR 0002), written as a JPEG to [file].
typedef ThumbnailShot = ({Duration seek, String file});

/// Renders filmstrip thumbnails of a video. Windows runs the bundled
/// ffmpeg; Android will use `MediaMetadataRetriever` (CUTCAP-9).
abstract interface class ThumbnailSource {
  /// Writes each of [shots] of the video at [videoPath] as a JPEG [height]
  /// px tall, keeping the video's upright aspect. A shot that cannot be
  /// rendered leaves no file; a file only appears once it is complete.
  ///
  /// Throws when the video cannot be rendered at all.
  Future<void> render(
    String videoPath,
    List<ThumbnailShot> shots, {
    required int height,
  });
}
