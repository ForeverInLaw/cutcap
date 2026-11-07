import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/media/ffprobe_media_probe.dart';
import 'package:cutcap/media/media_probe.dart';
import 'package:flutter_test/flutter_test.dart';

/// ffprobe `-show_streams -show_format` output, trimmed to the fields that
/// matter, in the shape ffprobe 9 prints it.
String probeJson({
  String width = '1280',
  String height = '720',
  String rFrameRate = '30/1',
  String avgFrameRate = '30/1',
  String? streamDuration = '"4.000000"',
  String formatDuration = '4.021333',
  String sideData = '',
  String tags = '{}',
  bool audio = true,
}) =>
    '''
{
  "streams": [
    {
      "index": 0,
      "codec_name": "h264",
      "codec_type": "video",
      "width": $width,
      "height": $height,
      "r_frame_rate": "$rFrameRate",
      "avg_frame_rate": "$avgFrameRate",
      ${streamDuration == null ? '' : '"duration": $streamDuration,'}
      "tags": $tags
      $sideData
    }${audio ? ''',
    {
      "index": 1,
      "codec_name": "aac",
      "codec_type": "audio",
      "r_frame_rate": "0/0",
      "duration": "4.021333"
    }''' : ''}
  ],
  "format": {
    "filename": "a.mp4",
    "duration": "$formatDuration"
  }
}''';

Source parse(String json) =>
    FfprobeMediaProbe.parse(json, path: 'D:/media/a.mp4');

void main() {
  test('reads geometry, exact rate, duration and audio of a plain file', () {
    final source = parse(probeJson());

    expect(source.path, 'D:/media/a.mp4');
    expect(source.resolution, (width: 1280, height: 720));
    expect(source.frameRate, const FrameRate(30, 1));
    expect(source.duration, const Duration(seconds: 4));
    expect(source.rotation, 0);
    expect(source.hasAudio, isTrue);
  });

  test('keeps an NTSC rate as an exact ratio', () {
    final source = parse(
      probeJson(rFrameRate: '30000/1001', avgFrameRate: '30000/1001'),
    );

    expect(source.frameRate, const FrameRate(30000, 1001));
  });

  test('reads a decimal duration to the microsecond', () {
    final source = parse(probeJson(streamDuration: '"2.033333"'));

    expect(source.duration, const Duration(microseconds: 2033333));
  });

  test('falls back to the container duration when the stream has none', () {
    final source = parse(
      probeJson(streamDuration: null, formatDuration: '6.250000'),
    );

    expect(source.duration, const Duration(milliseconds: 6250));
  });

  test('reports no audio when the file has no audio stream', () {
    expect(parse(probeJson(audio: false)).hasAudio, isFalse);
  });

  test('turns a display matrix rotation into a clockwise upright turn', () {
    // ffprobe reports the matrix rotation counter-clockwise; a phone's
    // portrait recording carries -90, shown upright by turning 90° clockwise.
    String rotated(int degrees) => probeJson(
      sideData:
          ''',
      "side_data_list": [
        {"side_data_type": "Display Matrix", "rotation": $degrees}
      ]''',
    );

    expect(parse(rotated(-90)).rotation, 90);
    expect(parse(rotated(90)).rotation, 270);
    expect(parse(rotated(180)).rotation, 180);
    expect(parse(rotated(-180)).rotation, 180);
  });

  test('reads the legacy rotate tag as a clockwise turn', () {
    final source = parse(probeJson(tags: '{"rotate": "90"}'));

    expect(source.rotation, 90);
  });

  test('uses the average rate when the nominal one is unknown', () {
    final source = parse(probeJson(rFrameRate: '0/0', avgFrameRate: '25/1'));

    expect(source.frameRate, const FrameRate(25, 1));
  });

  test('rejects a file without a video stream as undecodable', () {
    const audioOnly = '''
{
  "streams": [{"index": 0, "codec_type": "audio", "duration": "3.0"}],
  "format": {"duration": "3.0"}
}''';

    expect(
      () => parse(audioOnly),
      throwsA(
        isA<UndecodableMedia>().having((e) => e.path, 'path', 'D:/media/a.mp4'),
      ),
    );
  });

  test('rejects output ffprobe could not make sense of', () {
    expect(() => parse('{\n\n}'), throwsA(isA<UndecodableMedia>()));
    expect(() => parse('not json'), throwsA(isA<UndecodableMedia>()));
    expect(
      () => parse(probeJson(streamDuration: null, formatDuration: '0.000000')),
      throwsA(isA<UndecodableMedia>()),
    );
  });
}
