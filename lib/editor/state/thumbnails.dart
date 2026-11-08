import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/editor_session.dart';
import '../../media/thumbnail_cache.dart';
import '../../media/thumbnail_image.dart';
import '../../media/thumbnail_source.dart';
import '../../platform/platform_services.dart';
import '../editor_view_state.dart';
import '../filmstrip.dart';

/// Renders filmstrip thumbnails: ffmpeg on desktop, MediaMetadataRetriever
/// on Android. Null when ffmpeg is missing; the filmstrip then keeps its
/// solid frames.
final thumbnailSourceProvider = Provider<ThumbnailSource?>(
  (ref) => ref.watch(platformServicesProvider).thumbnailSource,
);

/// Thumbnails on disk in the app's cache directory.
final thumbnailCacheProvider = Provider<ThumbnailCache?>((ref) {
  final source = ref.watch(thumbnailSourceProvider);
  if (source == null) return null;
  return ThumbnailCache(
    source: source,
    directory: () async => Directory(
      p.join((await getApplicationCacheDirectory()).path, 'thumbnails'),
    ),
    stamp: ref.watch(platformServicesProvider).thumbnailStamp,
  );
});

/// The filmstrip of [clip] cut from [source], drawn from [cache].
FilmstripFrame filmstripOf(ThumbnailCache cache, Clip clip, Source source) {
  final grid = source.frameRate;
  return (start, span, pixelHeight) {
    final frame = Filmstrip.frameFor(
      grid: grid,
      inPoint: clip.inPoint,
      outPoint: clip.outPoint,
      cellStart: start,
      cellSpan: span,
    );
    return ThumbnailImage(
      cache,
      videoPath: source.path,
      seek: grid.seekTarget(grid.frameStart(frame)),
      height: pixelHeight,
    );
  };
}
