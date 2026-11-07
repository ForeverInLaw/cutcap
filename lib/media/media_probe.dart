import '../domain/source.dart';

/// Reads what the editor needs to know about a video file: duration,
/// geometry, rotation, exact frame rate and whether it has audio.
abstract interface class MediaProbe {
  /// Probes the file at [path]. The returned source's id is derived from
  /// the path, so probing the same file twice yields the same [SourceId].
  ///
  /// Throws a [MediaProbeException] when the file cannot be used.
  Future<Source> probe(String path);
}

/// Why a file could not be probed.
sealed class MediaProbeException implements Exception {
  const MediaProbeException(this.path);

  /// The file that was probed.
  final String path;
}

/// The file is not a video this device can decode (missing, not a media
/// file, no video stream, or no usable length).
final class UndecodableMedia extends MediaProbeException {
  const UndecodableMedia(super.path, this.reason);

  /// Diagnostic detail, not for display.
  final String reason;

  @override
  String toString() => 'UndecodableMedia($path): $reason';
}

/// The tool that probes files is not installed.
final class ProbeToolMissing extends MediaProbeException {
  const ProbeToolMissing(super.path, this.tool);

  final String tool;

  @override
  String toString() => 'ProbeToolMissing($path): $tool not found';
}
