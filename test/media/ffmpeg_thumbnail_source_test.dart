// Real thumbnails with the ffmpeg on PATH, measured with ffprobe.
@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:cutcap/media/ffmpeg_thumbnail_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/ffmpeg_tools.dart';

void main() {
  final skip = ffmpegSkip();
  late Directory dir;
  late String video;

  setUpAll(() async {
    if (skip != false) return;
    dir = await Directory.systemTemp.createTemp('cutcap_ffthumbs_');
    video = p.join(dir.path, 'clip.mp4');
    final made = await Process.run('ffmpeg', [
      ...['-v', 'error', '-f', 'lavfi', '-i', 'testsrc=s=320x240:r=25:d=2'],
      ...['-c:v', 'libx264', '-pix_fmt', 'yuv420p', video],
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
  });

  tearDownAll(() async {
    if (skip == false) await dir.delete(recursive: true);
  });

  Future<(int, int)> sizeOf(String image) async {
    final probe = await Process.run('ffprobe', [
      ...['-v', 'error', '-print_format', 'json', '-show_streams', image],
    ]);
    final stream = ((jsonDecode('${probe.stdout}') as Map)['streams'] as List)
        .cast<Map<String, Object?>>()
        .single;
    return (stream['width']! as int, stream['height']! as int);
  }

  test('writes a JPEG of the asked height per shot, skipping shots past '
      'the end', () async {
    String shot(String name) => p.join(dir.path, name);

    await const FfmpegThumbnailSource('ffmpeg').render(video, [
      (seek: Duration.zero, file: shot('first.jpg')),
      // The last frame starts at 1.96 s; seeks aim half a frame early.
      (seek: const Duration(milliseconds: 1940), file: shot('last.jpg')),
      (seek: const Duration(seconds: 30), file: shot('past.jpg')),
    ], height: 96);

    expect(await sizeOf(shot('first.jpg')), (128, 96));
    expect(await sizeOf(shot('last.jpg')), (128, 96));
    expect(File(shot('past.jpg')).existsSync(), isFalse);
    expect(
      dir.listSync().map((entry) => p.basename(entry.path)),
      isNot(contains(endsWith('.part'))),
    );
  }, skip: skip);
}
