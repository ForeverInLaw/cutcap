import '../platform/android_channels.dart';
import 'thumbnail_source.dart';

/// [ThumbnailSource] on Android: `MediaMetadataRetriever` in the Kotlin
/// `MediaChannel` takes the sync frame nearest each shot (ADR 0002; a
/// filmstrip needs no exact frames), upright and scaled to the height,
/// and writes it as a JPEG.
final class AndroidThumbnailSource implements ThumbnailSource {
  const AndroidThumbnailSource();

  @override
  Future<void> render(
    String videoPath,
    List<ThumbnailShot> shots, {
    required int height,
  }) async {
    if (shots.isEmpty) return;
    await AndroidChannels.media.invokeMethod<int>('thumbnails', {
      'path': videoPath,
      'height': height,
      'shots': [
        for (final shot in shots)
          {'seekUs': shot.seek.inMicroseconds, 'file': shot.file},
      ],
    });
  }
}
