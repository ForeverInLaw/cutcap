import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/media/android_media_probe.dart';
import 'package:cutcap/media/media_probe.dart';
import 'package:flutter_test/flutter_test.dart';

const _uri = 'content://media/external/video/media/42';

/// Presentation times of [count] frames at [numerator]/[denominator] fps,
/// truncated to microseconds the way MediaExtractor reports them.
List<int> frameTimes(int count, int numerator, [int denominator = 1]) => [
  for (var k = 0; k < count; k++) k * denominator * 1000000 ~/ numerator,
];

/// The report the Kotlin probe sends back, with a plain 30 fps file by
/// default.
Map<Object?, Object?> report({
  String? name = 'a.mp4',
  bool hasVideo = true,
  bool decodable = true,
  int width = 1920,
  int height = 1080,
  int rotation = 0,
  int? durationUs = 4000000,
  int? containerDurationUs = 4021000,
  List<int>? sampleTimesUs,
  num? trackFrameRate,
  int? frameCount = 120,
  int? videoBitRate,
  List<int?> audioBitRates = const [192000],
  int? containerBitRate,
}) => {
  'name': name,
  'video': hasVideo
      ? {
          'mime': 'video/avc',
          'decodable': decodable,
          'width': width,
          'height': height,
          'rotation': rotation,
          'durationUs': durationUs,
          'sampleTimesUs': sampleTimesUs ?? frameTimes(120, 30),
          'frameRate': trackFrameRate,
          'bitRate': videoBitRate,
        }
      : null,
  'audio': [
    for (final bitRate in audioBitRates)
      {'mime': 'audio/mp4a-latm', 'bitRate': bitRate},
  ],
  'frameCount': frameCount,
  'durationUs': containerDurationUs,
  'bitRate': containerBitRate,
};

Source parse(Map<Object?, Object?> report) =>
    AndroidMediaProbe.parse(report, path: _uri);

void main() {
  test('reads geometry, length, audio and name of a plain file', () {
    final source = parse(report());

    expect(source.id, const SourceId(_uri));
    expect(source.path, _uri);
    expect(source.name, 'a.mp4');
    expect(source.resolution, (width: 1920, height: 1080));
    expect(source.rotation, 0);
    expect(source.duration, const Duration(seconds: 4));
    expect(source.frameRate, const FrameRate(30, 1));
    expect(source.averageFrameRate, const FrameRate(30, 1));
    expect(source.hasAudio, isTrue);
  });

  group('frame rate', () {
    test('recovers an NTSC rate from truncated, decode-ordered times', () {
      // B-frames arrive out of presentation order.
      final times = frameTimes(90, 30000, 1001);
      final decodeOrder = [
        for (var i = 0; i + 3 <= times.length; i += 3) ...[
          times[i],
          times[i + 2],
          times[i + 1],
        ],
      ];
      final source = parse(
        report(
          sampleTimesUs: decodeOrder,
          frameCount: 179,
          durationUs: 5972633,
        ),
      );

      expect(source.frameRate, const FrameRate(30000, 1001));
    });

    test('takes the dominant interval of a variable-rate file, and the '
        'average over the whole file', () {
      // 3 s at 30 fps, then 3 s at 20 fps (ADR 0002 fixture d).
      final times = [
        ...frameTimes(90, 30),
        for (var k = 0; k < 60; k++) 3000000 + k * 50000,
      ];
      final source = parse(
        report(sampleTimesUs: times, frameCount: 150, durationUs: 6000000),
      );

      expect(source.frameRate, const FrameRate(30, 1));
      expect(source.averageFrameRate, const FrameRate(25, 1));
    });

    test('keeps camera jitter on the standard rate', () {
      final jittered = [
        for (var k = 0; k < 60; k++) k * 33333 + (k.isEven ? 0 : 400),
      ];

      expect(
        parse(report(sampleTimesUs: jittered)).frameRate,
        const FrameRate(30, 1),
      );
    });

    test('keeps an unusual rate to the millihertz', () {
      final source = parse(report(sampleTimesUs: frameTimes(40, 37, 2)));

      expect(source.frameRate, const FrameRate(37, 2));
    });

    test('falls back to the track header for a single-frame file', () {
      final source = parse(
        report(sampleTimesUs: const [0], trackFrameRate: 24.0),
      );

      expect(source.frameRate, const FrameRate(24, 1));
    });

    test('leaves the average unknown without a frame count', () {
      expect(parse(report(frameCount: null)).averageFrameRate, isNull);
    });
  });

  test('turns rotation to a quarter turn clockwise', () {
    expect(parse(report(rotation: 90)).rotation, 90);
    expect(parse(report(rotation: 270)).rotation, 270);
    expect(parse(report(rotation: -90)).rotation, 270);
  });

  group('video bitrate', () {
    test("is the video track's own when known", () {
      final source = parse(
        report(videoBitRate: 8000000, containerBitRate: 9000000),
      );

      expect(source.videoBitRate, 8000000);
    });

    test("is the container's minus its audio otherwise", () {
      final source = parse(
        report(containerBitRate: 9000000, audioBitRates: const [192000, null]),
      );

      expect(source.videoBitRate, 9000000 - 192000);
    });

    test('is unknown when neither is reported', () {
      expect(parse(report()).videoBitRate, isNull);
    });
  });

  test('a file without audio tracks has no audio', () {
    expect(parse(report(audioBitRates: const [])).hasAudio, isFalse);
  });

  test('takes the container length when the track has none', () {
    final source = parse(report(durationUs: null));

    expect(source.duration, const Duration(microseconds: 4021000));
  });

  test('names the file by its path when the system gives no name', () {
    const path = '/storage/emulated/0/Movies/b.mp4';
    final source = AndroidMediaProbe.parse(report(name: null), path: path);

    expect(source.name, 'b.mp4');
  });

  test('names a rejected file as the system shows it', () {
    expect(
      () => parse(report(name: 'clip.webm', decodable: false)),
      throwsA(
        isA<UndecodableMedia>().having((e) => e.name, 'name', 'clip.webm'),
      ),
    );
  });

  group('rejects', () {
    for (final (what, bad) in [
      ('a file without video', report(hasVideo: false)),
      ('video this device cannot decode', report(decodable: false)),
      ('a track without a size', report(width: 0)),
      (
        'a file without a length',
        report(durationUs: null, containerDurationUs: null),
      ),
      ('a file without a frame rate', report(sampleTimesUs: const [])),
    ]) {
      test(what, () {
        expect(() => parse(bad), throwsA(isA<UndecodableMedia>()));
      });
    }
  });
}
