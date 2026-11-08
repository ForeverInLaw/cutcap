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

/// Seconds as ffmpeg reads them, in whole microseconds.
Duration seconds(String value) =>
    Duration(microseconds: (double.parse(value) * 1e6).round());

// What the command must get right for the engine to work; the exact
// options and filter graph are checked by running them in
// ffmpeg_export_integration_test.dart.
void main() {
  final a = source('a');
  final silent = source('silent', hasAudio: false);

  test('opens each clip as its own input, sought to its planned start', () {
    final planned = plan([
      (a, 2033333, 3000000),
      (silent, 0, 1000000),
      (a, 0, 500000),
    ]);
    final arguments = ffmpegExportArguments(
      planned,
      H264Encoder.x264,
      'C:/out/cut.mp4',
    );

    expect(valuesOf(arguments, '-i'), [a.path, silent.path, a.path]);
    expect(valuesOf(arguments, '-ss').map(seconds), [
      for (final clip in planned.clips) clip.seek,
    ]);
  });

  test('never reads audio from a source that has none', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 0, 1000000), (silent, 0, 1000000)]),
      H264Encoder.x264,
      'C:/out/cut.mp4',
    );
    final graph = valuesOf(arguments, '-filter_complex').single;

    expect(graph, contains('[0:a'));
    expect(graph, isNot(contains('[1:a')));
  });

  test('encodes with the chosen encoder into an mp4 at the given path', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 0, 1000000)]),
      H264Encoder.mediaFoundation,
      'C:/out/cut.mp4.part',
    );

    expect(valuesOf(arguments, '-c:v'), ['h264_mf']);
    expect(valuesOf(arguments, '-c:a'), ['aac']);
    // The .part name has no extension ffmpeg could take the format from.
    expect(valuesOf(arguments, '-f'), ['mp4']);
    expect(arguments.last, 'C:/out/cut.mp4.part');
  });

  test('reports progress on stdout and never waits for input', () {
    final arguments = ffmpegExportArguments(
      plan([(a, 0, 1000000)]),
      H264Encoder.x264,
      'C:/out/cut.mp4',
    );

    expect(valuesOf(arguments, '-progress'), ['pipe:1']);
    expect(arguments, contains('-nostdin'));
  });
}
