import 'dart:io';

import 'media_tools.dart';
import 'thumbnail_source.dart';

/// [ThumbnailSource] on ffmpeg (desktop): one process per call with an
/// exact `-ss` input per shot (ADR 0002), each scaled to the height and
/// written as a JPEG. ffmpeg turns rotated videos upright by itself.
final class FfmpegThumbnailSource implements ThumbnailSource {
  const FfmpegThumbnailSource(this.ffmpegPath);

  final String ffmpegPath;

  /// JPEG quality on ffmpeg's 2 (best) to 31 scale; thumbnails are small.
  static const _quality = '5';

  @override
  Future<void> render(
    String videoPath,
    List<ThumbnailShot> shots, {
    required int height,
  }) async {
    if (shots.isEmpty) return;
    final result = await Process.run(ffmpegPath, [
      ...['-hide_banner', '-nostdin', '-y', '-loglevel', 'error'],
      for (final shot in shots) ...[
        '-ss',
        ffmpegSeconds(shot.seek),
        '-i',
        videoPath,
      ],
      for (final (i, shot) in shots.indexed) ...[
        ...['-map', '$i:v:0', '-frames:v', '1', '-vf', 'scale=-2:$height'],
        // Full-range 4:2:0 is the only YUV that mjpeg takes without
        // complaint from every source.
        ...['-c:v', 'mjpeg', '-pix_fmt', 'yuvj420p', '-q:v', _quality],
        ...['-f', 'image2', '-update', '1'],
        _partial(shot),
      ],
    ]);
    // A shot past the end of the video yields no frame; keep the others.
    var rendered = 0;
    for (final shot in shots) {
      final partial = File(_partial(shot));
      if (!await partial.exists()) continue;
      if (await partial.length() > 0) {
        await partial.rename(shot.file);
        rendered++;
      } else {
        await partial.delete();
      }
    }
    if (rendered == 0 && result.exitCode != 0) {
      throw ProcessException(
        ffmpegPath,
        const [],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }

  static String _partial(ThumbnailShot shot) => '${shot.file}.part';
}
