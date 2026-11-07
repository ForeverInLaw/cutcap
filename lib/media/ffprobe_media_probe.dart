import 'dart:convert';
import 'dart:io';

import '../domain/editor_session.dart';
import 'media_probe.dart';
import 'media_tools.dart';

/// [MediaProbe] that runs `ffprobe` (desktop) and reads its JSON report.
final class FfprobeMediaProbe implements MediaProbe {
  const FfprobeMediaProbe({this.locator = const MediaToolLocator()});

  final MediaToolLocator locator;

  @override
  Future<Source> probe(String path) async {
    final ffprobe = locator.find(MediaTool.ffprobe);
    if (ffprobe == null) {
      throw ProbeToolMissing(path, MediaTool.ffprobe.command);
    }
    final result = await Process.run(ffprobe, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_streams',
      '-show_format',
      path,
    ], stdoutEncoding: utf8);
    if (result.exitCode != 0) {
      throw UndecodableMedia(path, '${result.stderr}'.trim());
    }
    return parse('${result.stdout}', path: path);
  }

  /// The [Source] described by ffprobe's `-show_streams -show_format` JSON
  /// for the file at [path]. The first video stream is the picture; the
  /// source's id is its path.
  ///
  /// Throws [UndecodableMedia] when there is no video stream with a size and
  /// a positive length.
  static Source parse(String json, {required String path}) {
    Never fail(String reason) => throw UndecodableMedia(path, reason);

    final Object? report;
    try {
      report = jsonDecode(json);
    } on FormatException catch (error) {
      fail('unreadable ffprobe output: ${error.message}');
    }
    if (report case {'streams': final List<Object?> streams}) {
      final video = streams
          .whereType<Map<String, Object?>>()
          .where((stream) => stream['codec_type'] == 'video')
          .firstOrNull;
      if (video == null) fail('no video stream');
      final (width, height) = switch (video) {
        {'width': final int width, 'height': final int height}
            when width > 0 && height > 0 =>
          (width, height),
        _ => fail('no frame size'),
      };
      final duration =
          _seconds(video['duration']) ??
          _seconds(switch (report) {
            {'format': {'duration': final Object? duration}} => duration,
            _ => null,
          });
      if (duration == null || duration <= Duration.zero) fail('no duration');
      final rate =
          _rate(video['r_frame_rate']) ??
          _rate(video['avg_frame_rate']) ??
          fail('no frame rate');
      return Source(
        id: SourceId(path),
        path: path,
        duration: duration,
        resolution: (width: width, height: height),
        rotation: _clockwiseRotation(video),
        frameRate: rate,
        hasAudio: streams.whereType<Map<String, Object?>>().any(
          (stream) => stream['codec_type'] == 'audio',
        ),
      );
    }
    fail('no streams');
  }

  /// ffprobe prints times as decimal seconds ("2.033333"); read them to the
  /// microsecond without going through floating point.
  static Duration? _seconds(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
    if (match == null) return null;
    final fraction = (match[2] ?? '').padRight(6, '0').substring(0, 6);
    return Duration(
      seconds: int.parse(match[1]!),
      microseconds: int.parse(fraction),
    );
  }

  /// "30000/1001" as an exact rate; null for "0/0" and other unknowns.
  static FrameRate? _rate(Object? value) {
    if (value is! String) return null;
    final [numerator, denominator] = switch (value.split('/')) {
      [final n, final d] => [int.tryParse(n) ?? 0, int.tryParse(d) ?? 0],
      _ => [0, 0],
    };
    return numerator > 0 && denominator > 0
        ? FrameRate(numerator, denominator)
        : null;
  }

  /// The clockwise turn that shows the stream upright. The display matrix
  /// rotation is counter-clockwise; the legacy `rotate` tag is clockwise.
  static int _clockwiseRotation(Map<String, Object?> video) {
    final matrix = switch (video['side_data_list']) {
      final List<Object?> sideData =>
        sideData
            .map(
              (entry) => switch (entry) {
                {
                  'side_data_type': 'Display Matrix',
                  'rotation': final num degrees,
                } =>
                  degrees,
                _ => null,
              },
            )
            .nonNulls
            .firstOrNull,
      _ => null,
    };
    final clockwise = matrix != null
        ? -matrix
        : switch (video['tags']) {
            {'rotate': final String degrees} => num.tryParse(degrees) ?? 0,
            _ => 0,
          };
    return ((clockwise / 90).round() * 90) % 360;
  }
}
