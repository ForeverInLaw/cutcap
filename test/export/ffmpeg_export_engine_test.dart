import 'dart:async';

import 'package:cutcap/domain/edit_list.dart';
import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/domain/source.dart';
import 'package:cutcap/export/encoder_probe.dart';
import 'package:cutcap/export/export_engine.dart';
import 'package:cutcap/export/ffmpeg_export_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = Source(
  id: const SourceId('a'),
  path: 'C:/videos/a.mp4',
  duration: const Duration(seconds: 2),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: true,
);

final _oneClip = EditList(
  clips: [
    Clip(
      id: const ClipId(0),
      sourceId: const SourceId('a'),
      inPoint: Duration.zero,
      outPoint: const Duration(seconds: 1),
    ),
  ],
  sources: {const SourceId('a'): _source},
);

void main() {
  test('fails when every source is missing', () async {
    final engine = FfmpegExportEngine(ffmpegPath: 'ffmpeg');

    final events = await engine
        .export(
          ExportJob(
            editList: _oneClip,
            outputPath: 'out.mp4',
            missingSources: const {SourceId('a')},
          ),
        )
        .toList();

    expect(events, [
      isA<ExportFailed>().having(
        (failed) => failed.kind,
        'kind',
        ExportFailure.nothingToExport,
      ),
    ]);
  });

  test('fails with the path when ffmpeg cannot be started', () async {
    final engine = FfmpegExportEngine(ffmpegPath: 'Z:/nowhere/ffmpeg.exe');

    final events = await engine
        .export(ExportJob(editList: _oneClip, outputPath: 'out.mp4'))
        .toList();

    expect(events, [
      isA<ExportFailed>()
          .having((failed) => failed.kind, 'kind', ExportFailure.cannotStart)
          .having(
            (failed) => failed.detail,
            'detail',
            contains('Z:/nowhere/ffmpeg.exe'),
          ),
    ]);
  });

  group('while the encoder is still being probed', () {
    late Completer<int> probing;
    late FfmpegExportEngine engine;

    setUp(() {
      probing = Completer();
      engine = FfmpegExportEngine(
        ffmpegPath: 'ffmpeg',
        encoders: EncoderProbe((_) => probing.future),
      );
    });

    final job = ExportJob(editList: _oneClip, outputPath: 'out.mp4');

    test('cancel ends the export at once', () async {
      final events = engine.export(job).toList();
      await pumpEventQueue();

      engine.cancel();

      expect(await events.timeout(const Duration(seconds: 1)), [
        isA<ExportCancelled>(),
      ]);
    });

    test('dropping the subscription frees the engine at once', () async {
      final subscription = engine.export(job).listen((_) {});
      await pumpEventQueue();

      await subscription.cancel().timeout(const Duration(seconds: 1));

      // A second export would be refused while the first still ran.
      final next = engine
          .export(job)
          .listen((_) {}, onError: (Object error) => fail('$error'));
      await pumpEventQueue();
      await next.cancel();
    });
  });
}
