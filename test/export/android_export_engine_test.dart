import 'dart:async';

import 'package:cutcap/domain/edit_list.dart';
import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/domain/source.dart';
import 'package:cutcap/export/android_export_engine.dart';
import 'package:cutcap/export/export_engine.dart';
import 'package:cutcap/platform/android_channels.dart';
import 'package:flutter_test/flutter_test.dart';

Source _source(
  String uri, {
  FrameRate rate = const FrameRate(30, 1),
  bool hasAudio = true,
}) => Source(
  id: SourceId(uri),
  path: uri,
  duration: const Duration(seconds: 60),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: rate,
  hasAudio: hasAudio,
  videoBitRate: 8000000,
);

final _a = _source('content://media/external/video/media/1');
final _b = _source(
  'content://media/external/video/media/2',
  rate: const FrameRate(25, 1),
  hasAudio: false,
);

/// A at 30 fps from 1 s to 2 s, then B at 25 fps from 0 to 0.4 s.
final _edit = EditList(
  clips: [
    Clip(
      id: const ClipId(0),
      sourceId: _a.id,
      inPoint: const Duration(seconds: 1),
      outPoint: const Duration(seconds: 2),
    ),
    Clip(
      id: const ClipId(1),
      sourceId: _b.id,
      inPoint: Duration.zero,
      outPoint: const Duration(milliseconds: 400),
    ),
  ],
  sources: {_a.id: _a, _b.id: _b},
);

const _job = 'final-cut.mp4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Object?> requests;
  late List<String> methodCalls;
  late int platformCancels;

  /// The Kotlin side of a run: records the request, then lets [script]
  /// drive the sink.
  void platformRuns(void Function(MockStreamHandlerEventSink events) script) =>
      messenger.setMockStreamHandler(
        AndroidChannels.exportRun,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            requests.add(arguments);
            script(events);
          },
          onCancel: (_) => platformCancels++,
        ),
      );

  setUp(() {
    requests = [];
    methodCalls = [];
    platformCancels = 0;
    messenger.setMockMethodCallHandler(AndroidChannels.export, (call) async {
      methodCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockStreamHandler(AndroidChannels.exportRun, null);
    messenger.setMockMethodCallHandler(AndroidChannels.export, null);
  });

  ExportJob job([EditList? editList]) =>
      ExportJob(editList: editList ?? _edit, outputPath: _job);

  test('sends the plan and reports progress, then the saved video', () async {
    platformRuns((events) {
      events
        ..success({'event': 'progress', 'fraction': 0.5})
        ..success({
          'event': 'succeeded',
          'uri': 'content://media/external/video/media/99',
          'name': 'final-cut (1).mp4',
        })
        ..endOfStream();
    });

    final events = await AndroidExportEngine().export(job()).toList();

    expect(requests.single, {
      'name': 'final-cut.mp4',
      'width': 1280,
      'height': 720,
      'frameRateNumerator': 30,
      'frameRateDenominator': 1,
      'videoBitRate': 8000000,
      'clips': [
        // Each clip starts half a frame before its in point (ADR 0002) and
        // lasts as long as it does on the track.
        {
          'uri': 'content://media/external/video/media/1',
          'startUs': 983334,
          'endUs': 1983334,
        },
        {
          'uri': 'content://media/external/video/media/2',
          'startUs': 0,
          'endUs': 400000,
        },
      ],
    });
    expect(events, [
      isA<ExportProgress>().having((e) => e.fraction, 'fraction', 0.5),
      isA<ExportSucceeded>()
          .having(
            (e) => e.outputPath,
            'outputPath',
            'content://media/external/video/media/99',
          )
          .having((e) => e.displayName, 'displayName', 'final-cut (1).mp4'),
    ]);
  });

  test('reports a failure with its reason', () async {
    platformRuns((events) {
      events
        ..success({
          'event': 'failed',
          'reason': 'ERROR_CODE_DECODING_FAILED: no decoder',
        })
        ..endOfStream();
    });

    final events = await AndroidExportEngine().export(job()).toList();

    expect(events, [
      isA<ExportFailed>().having(
        (e) => e.reason,
        'reason',
        'ERROR_CODE_DECODING_FAILED: no decoder',
      ),
    ]);
  });

  test('a refused start is a failure with the platform reason', () async {
    platformRuns((events) {
      events
        ..error(code: 'busy', message: 'An export is already running.')
        ..endOfStream();
    });

    final events = await AndroidExportEngine().export(job()).toList();

    expect(events, [
      isA<ExportFailed>().having(
        (e) => e.reason,
        'reason',
        'An export is already running.',
      ),
    ]);
  });

  test('fails without asking the platform when every source is missing', () {
    final engine = AndroidExportEngine();
    final events = engine
        .export(
          ExportJob(
            editList: _edit,
            outputPath: _job,
            missingSources: {_a.id, _b.id},
          ),
        )
        .toList();

    expect(events, completion([isA<ExportFailed>()]));
    expect(requests, isEmpty);
  });

  test('cancel asks the platform, which ends the run as cancelled', () async {
    late MockStreamHandlerEventSink sink;
    platformRuns((events) => sink = events);
    messenger.setMockMethodCallHandler(AndroidChannels.export, (call) async {
      methodCalls.add(call.method);
      sink
        ..success({'event': 'cancelled'})
        ..endOfStream();
      return null;
    });
    final engine = AndroidExportEngine();
    final events = engine.export(job()).toList();
    await pumpEventQueue();

    engine.cancel();

    expect(await events, [isA<ExportCancelled>()]);
    expect(methodCalls, ['cancel']);
  });

  test('cancel does nothing when no export runs', () async {
    AndroidExportEngine().cancel();
    await pumpEventQueue();

    expect(methodCalls, isEmpty);
  });

  test('dropping the subscription stops the platform run', () async {
    platformRuns(
      (events) => events.success({'event': 'progress', 'fraction': 0.1}),
    );
    final engine = AndroidExportEngine();
    final first = Completer<void>();
    final subscription = engine.export(job()).listen((_) => first.complete());
    await first.future;

    await subscription.cancel();
    await pumpEventQueue();

    expect(platformCancels, 1);
  });

  test('refuses a second export while one runs, then takes the next', () async {
    platformRuns((_) {});
    final engine = AndroidExportEngine();
    final running = engine.export(job()).listen(null);
    await pumpEventQueue();

    expect(engine.export(job()).toList(), throwsStateError);

    await running.cancel();
    await pumpEventQueue();
    platformRuns(
      (events) => events
        ..success({'event': 'cancelled'})
        ..endOfStream(),
    );
    expect(await engine.export(job()).toList(), [isA<ExportCancelled>()]);
  });
}
