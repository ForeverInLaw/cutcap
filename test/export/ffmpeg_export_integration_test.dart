// Seam 2 of the spec: real exports with the ffmpeg on PATH, checked with
// ffprobe. Fixtures are generated with lavfi so the commands must also work
// with the older distro ffmpeg on Ubuntu CI.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cutcap/domain/edit_list.dart';
import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/domain/source.dart';
import 'package:cutcap/export/export_engine.dart';
import 'package:cutcap/export/ffmpeg_export_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _tags = ['ffmpeg'];

void main() {
  final missing = ['ffmpeg', 'ffprobe'].where((tool) => !_runs(tool)).toList();
  final skip = missing.isEmpty ? false : '${missing.join(' and ')} not on PATH';

  late Directory dir;
  late Fixtures fixtures;

  setUpAll(() async {
    if (missing.isNotEmpty) return;
    dir = await Directory.systemTemp.createTemp('cutcap_export_');
    fixtures = await Fixtures.generate(dir);
  });

  tearDownAll(() async {
    if (missing.isEmpty) await dir.delete(recursive: true);
  });

  String output(String name) => '${dir.path}${Platform.pathSeparator}$name';

  Future<List<ExportEvent>> export(
    EditList editList,
    String outputPath, {
    FfmpegExportEngine? engine,
  }) => (engine ?? FfmpegExportEngine(ffmpegPath: 'ffmpeg'))
      .export(ExportJob(editList: editList, outputPath: outputPath))
      .toList();

  test(
    'mixed sizes, rates and a clip without audio follow the first clip',
    () async {
      final path = output('mixed.mp4');
      // An existing file is replaced.
      File(path).writeAsStringSync('old');

      final events = await export(
        editOf([
          (fixtures.hd30, 1000, 3000),
          (fixtures.vga25, 400, 2400),
          (fixtures.portrait60Silent, 500, 1500),
        ]),
        path,
      );

      expect(events.last, isA<ExportSucceeded>());
      expect(events.whereType<ExportProgress>(), isNotEmpty);
      final result = await Probed.of(path);
      expect(result.size, (width: 1280, height: 720));
      expect(result.frameRate, '30/1');
      result.expectDuration(const Duration(seconds: 5), fps: 30);
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'a portrait first clip without audio sets the format and gets silence',
    () async {
      final path = output('portrait.mp4');

      final events = await export(
        editOf([
          (fixtures.portrait60Silent, 0, 1000),
          (fixtures.hd30, 0, 1000),
        ]),
        path,
      );

      expect(events.last, isA<ExportSucceeded>());
      final result = await Probed.of(path);
      expect(result.size, (width: 720, height: 1280));
      expect(result.frameRate, '60/1');
      result.expectDuration(const Duration(seconds: 2), fps: 60);
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'a variable-rate first clip exports at its rounded average rate',
    () async {
      final path = output('vfr.mp4');

      final events = await export(
        // Across the change from 30 to 20 fps at 3 s; average 26 fps.
        editOf([(fixtures.vfr, 2000, 4000), (fixtures.vga25, 0, 1000)]),
        path,
      );

      expect(events.last, isA<ExportSucceeded>());
      final result = await Probed.of(path);
      expect(result.size, (width: 960, height: 540));
      expect(result.frameRate, '25/1');
      result.expectDuration(const Duration(seconds: 3), fps: 25);
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'a rotated first clip exports upright',
    () async {
      final rotated = fixtures.vgaRotated;
      if (rotated == null) {
        markTestSkipped('this ffmpeg cannot tag a rotated fixture');
        return;
      }
      final path = output('rotated.mp4');

      final events = await export(
        editOf([(rotated, 0, 1000), (fixtures.hd30, 0, 1000)]),
        path,
      );

      expect(events.last, isA<ExportSucceeded>());
      final result = await Probed.of(path);
      expect(result.size, (width: 480, height: 640));
      result.expectDuration(const Duration(seconds: 2), fps: 25);
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'cancel stops ffmpeg and leaves no file behind',
    () async {
      final path = output('cancelled.mp4');
      final engine = FfmpegExportEngine(ffmpegPath: 'ffmpeg');
      final events = <ExportEvent>[];

      await for (final event in engine.export(
        ExportJob(
          editList: editOf([
            for (var i = 0; i < 5; i++) (fixtures.hd30, 0, 4000),
          ]),
          outputPath: path,
        ),
      )) {
        events.add(event);
        if (event is ExportProgress) engine.cancel();
      }

      expect(events.last, isA<ExportCancelled>());
      expect(File(path).existsSync(), isFalse);
      expect(File('$path.part').existsSync(), isFalse);
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'dropping the subscription stops the export like cancel',
    () async {
      final path = output('dropped.mp4');
      final engine = FfmpegExportEngine(ffmpegPath: 'ffmpeg');
      final job = ExportJob(
        editList: editOf([
          for (var i = 0; i < 5; i++) (fixtures.hd30, 0, 4000),
        ]),
        outputPath: path,
      );

      final progressed = Completer<void>();
      final subscription = engine.export(job).listen((event) {
        if (event is ExportProgress && !progressed.isCompleted) {
          progressed.complete();
        }
      });
      await progressed.future;
      await subscription.cancel();

      expect(File(path).existsSync(), isFalse);
      expect(File('$path.part').existsSync(), isFalse);
      // The engine is free for the next export.
      expect(
        await engine.export(job).firstWhere((e) => e is ExportProgress),
        isA<ExportProgress>(),
      );
    },
    tags: _tags,
    skip: skip,
  );

  test(
    'a source ffmpeg cannot read fails with its message',
    () async {
      final path = output('failed.mp4');
      final broken = File(output('broken.mp4'))..writeAsStringSync('no video');

      final events = await export(
        editOf([(fixtures.hd30.copyAt(broken.path), 0, 1000)]),
        path,
      );

      expect(
        events.single,
        isA<ExportFailed>().having(
          (failed) => failed.reason,
          'reason',
          isNotEmpty,
        ),
      );
      expect(File(path).existsSync(), isFalse);
      expect(File('$path.part').existsSync(), isFalse);
    },
    tags: _tags,
    skip: skip,
  );
}

/// The generated sources, each as the media probe would describe it.
final class Fixtures {
  Fixtures._(
    this.hd30,
    this.vga25,
    this.portrait60Silent,
    this.vfr,
    this.vgaRotated,
  );

  /// 1280×720 at 30 fps with audio, 4 s.
  final Source hd30;

  /// 640×480 at 25 fps with 44.1 kHz audio, 3 s.
  final Source vga25;

  /// 720×1280 at 60 fps without audio, 2 s.
  final Source portrait60Silent;

  /// 960×540, 30 fps for 3 s then 20 fps for 2 s, with audio.
  final Source vfr;

  /// [vga25] with a 90° display rotation, or null when this ffmpeg cannot
  /// tag one.
  final Source? vgaRotated;

  static Future<Fixtures> generate(Directory dir) async {
    String at(String name) => '${dir.path}${Platform.pathSeparator}$name';
    // Options are written space-separated; paths are passed whole.
    const x264 = '-c:v libx264 -preset ultrafast -pix_fmt yuv420p';
    const aac = '-c:a aac -shortest';
    Future<void> make(String name, String options) =>
        _ffmpeg([...options.split(' '), at(name)]);

    await make(
      'hd30.mp4',
      '-f lavfi -i testsrc2=s=1280x720:r=30:d=4 '
          '-f lavfi -i sine=f=440:sample_rate=48000:d=4 $x264 -g 120 $aac',
    );
    await make(
      'vga25.mp4',
      '-f lavfi -i testsrc2=s=640x480:r=25:d=3 '
          '-f lavfi -i sine=f=880:sample_rate=44100:d=3 $x264 -g 75 $aac',
    );
    await make(
      'portrait60.mp4',
      '-f lavfi -i testsrc=s=720x1280:r=60:d=2 $x264',
    );
    await make(
      'vfr.mp4',
      '-f lavfi -i testsrc2=s=960x540:r=60:d=5 '
          '-f lavfi -i sine=f=660:sample_rate=48000:d=5 '
          "-vf select='if(lt(t,3),not(mod(n,2)),not(mod(n,3)))' "
          '-fps_mode vfr $x264 $aac',
    );
    final vfrRates = await Probed.of(at('vfr.mp4'));

    Source source(
      String name, {
      required int seconds,
      required Resolution resolution,
      required FrameRate rate,
      FrameRate? averageRate,
      int rotation = 0,
      bool hasAudio = true,
    }) => Source(
      id: SourceId(name),
      path: at(name),
      duration: Duration(seconds: seconds),
      resolution: resolution,
      rotation: rotation,
      frameRate: rate,
      averageFrameRate: averageRate,
      hasAudio: hasAudio,
    );

    return Fixtures._(
      source(
        'hd30.mp4',
        seconds: 4,
        resolution: (width: 1280, height: 720),
        rate: const FrameRate(30, 1),
      ),
      source(
        'vga25.mp4',
        seconds: 3,
        resolution: (width: 640, height: 480),
        rate: const FrameRate(25, 1),
      ),
      source(
        'portrait60.mp4',
        seconds: 2,
        resolution: (width: 720, height: 1280),
        rate: const FrameRate(60, 1),
        hasAudio: false,
      ),
      source(
        'vfr.mp4',
        seconds: 5,
        resolution: (width: 960, height: 540),
        rate: _rate(vfrRates.frameRate),
        averageRate: _rate(vfrRates.averageFrameRate),
      ),
      await _rotate(at('vga25.mp4'), at('vga25_rot90.mp4'))
          ? source(
              'vga25_rot90.mp4',
              seconds: 3,
              resolution: (width: 640, height: 480),
              rate: const FrameRate(25, 1),
              rotation: 90,
            )
          : null,
    );
  }

  /// Copies [from] to [to] with a 90° display rotation. The option for it
  /// changed across ffmpeg versions, so both are tried; true when [to] ends
  /// up rotated.
  static Future<bool> _rotate(String from, String to) async {
    for (final arguments in [
      ['-display_rotation:v:0', '90', '-i', from, '-c', 'copy', to],
      ['-i', from, '-c', 'copy', '-metadata:s:v:0', 'rotate=90', to],
    ]) {
      if (await _ffmpeg(arguments, check: false) == 0 &&
          (await Probed.of(to)).rotated) {
        return true;
      }
    }
    return false;
  }
}

/// What ffprobe reports about an export.
final class Probed {
  Probed._(this._video, this._audio);

  final Map<String, Object?> _video;
  final Map<String, Object?>? _audio;

  static Future<Probed> of(String path) async {
    final result = await Process.run('ffprobe', [
      ...'-v error -show_streams -of json'.split(' '),
      path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final streams =
        ((jsonDecode(result.stdout as String)
                    as Map<String, Object?>)['streams']!
                as List<Object?>)
            .cast<Map<String, Object?>>();
    Map<String, Object?>? stream(String type) =>
        streams.where((s) => s['codec_type'] == type).firstOrNull;
    return Probed._(stream('video')!, stream('audio'));
  }

  Resolution get size =>
      (width: _video['width']! as int, height: _video['height']! as int);

  String get frameRate => _video['r_frame_rate']! as String;
  String get averageFrameRate => _video['avg_frame_rate']! as String;

  bool get rotated {
    final sideData = (_video['side_data_list'] as List<Object?>?) ?? const [];
    final tags = (_video['tags'] as Map<String, Object?>?) ?? const {};
    return sideData.cast<Map<String, Object?>>().any(
          (d) => (d['rotation'] ?? 0) != 0,
        ) ||
        (tags['rotate'] ?? '0') != '0';
  }

  /// Asserts an H.264 video and an AAC 48 kHz stereo audio stream, each
  /// within one output frame of [expected].
  void expectDuration(Duration expected, {required int fps}) {
    final audio = _audio;
    expect(_video['codec_name'], 'h264');
    expect(audio, isNotNull, reason: 'no audio stream');
    expect(audio!['codec_name'], 'aac');
    expect(audio['sample_rate'], '48000');
    expect(audio['channels'], 2);
    final seconds = expected.inMicroseconds / Duration.microsecondsPerSecond;
    final frame = 1 / fps + 1e-6;
    expect(
      double.parse(_video['duration']! as String),
      closeTo(seconds, frame),
    );
    expect(double.parse(audio['duration']! as String), closeTo(seconds, frame));
  }
}

/// An edit list of (source, in ms, out ms) clips.
EditList editOf(List<(Source, int, int)> spans) => EditList(
  clips: [
    for (final (index, (source, inMs, outMs)) in spans.indexed)
      Clip(
        id: ClipId(index),
        sourceId: source.id,
        inPoint: Duration(milliseconds: inMs),
        outPoint: Duration(milliseconds: outMs),
      ),
  ],
  sources: {for (final (source, _, _) in spans) source.id: source},
);

extension on Source {
  /// This source, claimed to be at [path].
  Source copyAt(String path) => Source(
    id: SourceId(path),
    path: path,
    duration: duration,
    resolution: resolution,
    rotation: rotation,
    frameRate: frameRate,
    hasAudio: hasAudio,
  );
}

FrameRate _rate(String ratio) {
  final [numerator, denominator] = ratio.split('/').map(int.parse).toList();
  return FrameRate(numerator, denominator);
}

bool _runs(String tool) {
  try {
    return Process.runSync(tool, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<int> _ffmpeg(List<String> arguments, {bool check = true}) async {
  final result = await Process.run('ffmpeg', [
    ...'-hide_banner -nostdin -y -loglevel error'.split(' '),
    ...arguments,
  ]);
  if (check) expect(result.exitCode, 0, reason: '${result.stderr}');
  return result.exitCode;
}
