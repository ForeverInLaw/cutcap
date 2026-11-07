import 'package:cutcap/domain/edit_list.dart';
import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/domain/source.dart';
import 'package:cutcap/export/encoder_probe.dart';
import 'package:cutcap/export/export_plan.dart';
import 'package:cutcap/export/ffmpeg_command.dart';
import 'package:flutter_test/flutter_test.dart';

Source source(String id, {bool hasAudio = true}) => Source(
  id: SourceId(id),
  path: 'C:/videos/$id.mp4',
  duration: const Duration(seconds: 60),
  resolution: (width: 1920, height: 1080),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: hasAudio,
  videoBitRate: 8000000,
);

ExportPlan plan(List<(Source, int, int)> spans) => ExportPlan.of(
  EditList(
    clips: [
      for (final (index, (source, inUs, outUs)) in spans.indexed)
        Clip(
          id: ClipId(index),
          sourceId: source.id,
          inPoint: Duration(microseconds: inUs),
          outPoint: Duration(microseconds: outUs),
        ),
    ],
    sources: {for (final (source, _, _) in spans) source.id: source},
  ),
)!;

/// The value after each occurrence of [option].
List<String> valuesOf(List<String> arguments, String option) => [
  for (final (index, argument) in arguments.indexed)
    if (argument == option) arguments[index + 1],
];

void main() {
  final a = source('a');
  final silent = source('silent', hasAudio: false);

  test('opens each clip as its own input, sought to its first frame', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 2033333, 3000000), (silent, 0, 1000000), (a, 0, 500000)]),
      H264Encoder.x264,
      'C:/out/cut.mp4',
    );

    expect(valuesOf(arguments, '-i'), [a.path, silent.path, a.path]);
    expect(valuesOf(arguments, '-ss'), ['2.016667', '0.000000', '0.000000']);
  });

  test('fills a clip without audio with silence', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 0, 1000000), (silent, 0, 1000000)]),
      H264Encoder.x264,
      'C:/out/cut.mp4',
    );
    final graph = valuesOf(arguments, '-filter_complex').single;

    expect(graph, contains('[0:a:0]'));
    expect(graph, isNot(contains('[1:a')));
    expect(graph, contains('anullsrc'));
  });

  test('encodes H.264 with the chosen encoder and AAC into an mp4', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 0, 1000000)]),
      H264Encoder.mediaFoundation,
      'C:/out/cut.mp4.part',
    );
    final line = arguments.join(' ');

    expect(line, contains('-c:v h264_mf -hw_encoding 1'));
    expect(line, contains('-b:v 8000k -maxrate 12000k -bufsize 16000k'));
    expect(line, contains('-c:a aac -b:a 192k'));
    expect(line, contains('-f mp4'));
    expect(arguments.last, 'C:/out/cut.mp4.part');
  });

  test('reports progress on stdout and never waits for input', () {
    final line = ffmpegExportArguments(
      plan([(a, 0, 1000000)]),
      H264Encoder.x264,
      'C:/out/cut.mp4',
    ).join(' ');

    expect(line, contains('-progress pipe:1'));
    expect(line, contains('-nostdin'));
  });
}
