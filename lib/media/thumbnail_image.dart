import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'thumbnail_cache.dart';

/// A filmstrip frame from a [ThumbnailCache] as an [ImageProvider], so an
/// `Image` loads it in the background and Flutter's image cache keeps it
/// in memory. Equal for the same video, seek and height.
@immutable
final class ThumbnailImage extends ImageProvider<ThumbnailImage> {
  const ThumbnailImage(
    this.cache, {
    required this.videoPath,
    required this.seek,
    required this.height,
  });

  final ThumbnailCache cache;
  final String videoPath;
  final Duration seek;

  /// Pixel height to render at.
  final int height;

  @override
  Future<ThumbnailImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    ThumbnailImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _codec(decode), scale: 1);

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async {
    final bytes = await cache.thumbnail(videoPath, seek, height: height);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ThumbnailImage &&
      identical(other.cache, cache) &&
      other.videoPath == videoPath &&
      other.seek == seek &&
      other.height == height;

  @override
  int get hashCode => Object.hash(videoPath, seek, height);
}
