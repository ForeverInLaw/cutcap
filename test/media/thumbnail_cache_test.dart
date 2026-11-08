import 'dart:io';

import 'package:cutcap/media/thumbnail_cache.dart';
import 'package:cutcap/media/thumbnail_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Writes `<video name>@<seek µs>/<height>` as each frame's "JPEG", except
/// at [unrenderable] seeks, and records every render it was asked for.
final class _FakeSource implements ThumbnailSource {
  final renders = <(String video, List<int> seeks)>[];
  final unrenderable = <Duration>{};

  @override
  Future<void> render(
    String videoPath,
    List<ThumbnailShot> shots, {
    required int height,
  }) async {
    renders.add((
      p.basename(videoPath),
      [for (final shot in shots) shot.seek.inMicroseconds],
    ));
    for (final shot in shots) {
      if (unrenderable.contains(shot.seek)) continue;
      await File(shot.file).writeAsString(
        '${p.basename(videoPath)}@${shot.seek.inMicroseconds}/$height',
      );
    }
  }
}

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  late Directory dir;
  late String videoA;
  late String videoB;
  late _FakeSource source;

  ThumbnailCache cache() => ThumbnailCache(
    source: source,
    directory: () async => Directory(p.join(dir.path, 'thumbnails')),
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cutcap_thumbs_');
    videoA = p.join(dir.path, 'a.mp4');
    videoB = p.join(dir.path, 'b.mp4');
    await File(videoA).writeAsString('video a');
    await File(videoB).writeAsString('video b');
    source = _FakeSource();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<String> text(Future<List<int>> bytes) async =>
      String.fromCharCodes(await bytes);

  test('renders what is asked for in one pass per video', () async {
    final thumbnails = cache();
    final frames = await Future.wait([
      text(thumbnails.thumbnail(videoA, _ms(0), height: 96)),
      text(thumbnails.thumbnail(videoA, _ms(500), height: 96)),
      text(thumbnails.thumbnail(videoB, _ms(250), height: 96)),
      text(thumbnails.thumbnail(videoA, _ms(1000), height: 96)),
    ]);

    expect(frames, [
      'a.mp4@0/96',
      'a.mp4@500000/96',
      'b.mp4@250000/96',
      'a.mp4@1000000/96',
    ]);
    expect(source.renders, hasLength(2));
    expect(
      source.renders.firstWhere((render) => render.$1 == 'a.mp4').$2,
      unorderedEquals([0, 500000, 1000000]),
    );
  });

  test('asks once for a frame wanted twice at the same time', () async {
    final thumbnails = cache();
    await Future.wait([
      thumbnails.thumbnail(videoA, _ms(40), height: 96),
      thumbnails.thumbnail(videoA, _ms(40), height: 96),
    ]);

    expect(source.renders.single.$2, [40000]);
  });

  test('serves frames from disk on the next run', () async {
    await cache().thumbnail(videoA, _ms(40), height: 96);
    source.renders.clear();

    final frame = await text(cache().thumbnail(videoA, _ms(40), height: 96));

    expect(frame, 'a.mp4@40000/96');
    expect(source.renders, isEmpty);
  });

  test('renders again for another height or a changed video', () async {
    await cache().thumbnail(videoA, _ms(40), height: 96);
    await cache().thumbnail(videoA, _ms(40), height: 192);
    await File(videoA).writeAsString('video a, edited and longer');
    await cache().thumbnail(videoA, _ms(40), height: 96);

    expect(source.renders, hasLength(3));
  });

  test('gives up on a frame that cannot be rendered, once', () async {
    source.unrenderable.add(_ms(40));
    final thumbnails = cache();

    await expectLater(
      thumbnails.thumbnail(videoA, _ms(40), height: 96),
      throwsA(isA<ThumbnailUnavailable>()),
    );
    await expectLater(
      thumbnails.thumbnail(videoA, _ms(40), height: 96),
      throwsA(isA<ThumbnailUnavailable>()),
    );
    expect(source.renders, hasLength(1));
  });

  test('renders a video whose versions it cannot tell, keeping nothing '
      'on disk', () async {
    final thumbnails = ThumbnailCache(
      source: source,
      directory: () async => Directory(p.join(dir.path, 'thumbnails')),
      stamp: (_) async => const VideoUnversioned(),
    );

    final frame = await text(thumbnails.thumbnail(videoA, _ms(40), height: 96));

    expect(frame, 'a.mp4@40000/96');
    expect(
      Directory(
        p.join(dir.path, 'thumbnails'),
      ).listSync(recursive: true).whereType<File>(),
      isEmpty,
    );
  });

  test('renders nothing for a video that is gone', () async {
    await File(videoA).delete();

    await expectLater(
      cache().thumbnail(videoA, _ms(40), height: 96),
      throwsA(isA<ThumbnailUnavailable>()),
    );
    expect(source.renders, isEmpty);
  });
}
