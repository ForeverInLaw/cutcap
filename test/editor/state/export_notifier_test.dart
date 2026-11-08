import 'dart:async';

import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/editor/editor_view_state.dart';
import 'package:cutcap/editor/state/editor_state.dart';
import 'package:cutcap/editor/state/export_notifier.dart';
import 'package:cutcap/editor/state/view_state_provider.dart';
import 'package:cutcap/export/export_engine.dart' as engine;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Source _source(String path) => Source(
  id: SourceId(path),
  path: path,
  duration: const Duration(seconds: 4),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: true,
);

final _first = _source('D:/media/beach day.mov');
final _second = _source('D:/media/b.mp4');

/// An [engine.ExportEngine] whose exports the test drives by hand.
final class _FakeEngine implements engine.ExportEngine {
  final jobs = <engine.ExportJob>[];
  StreamController<engine.ExportEvent>? _run;

  void emit(engine.ExportEvent event) => _run!.add(event);

  /// Ends the running export with [outcome].
  Future<void> finish(engine.ExportOutcome outcome) async {
    final run = _run!;
    _run = null;
    run.add(outcome);
    await run.close();
  }

  @override
  Stream<engine.ExportEvent> export(engine.ExportJob job) {
    jobs.add(job);
    final run = _run = StreamController<engine.ExportEvent>();
    return run.stream;
  }

  @override
  void cancel() {
    if (_run != null) unawaited(finish(const engine.ExportCancelled()));
  }
}

void main() {
  late _FakeEngine fake;
  late ProviderContainer container;
  late List<String?> saveAnswers;
  late List<String> suggestedNames;
  late List<String> opened;
  late List<String> shared;

  ExportStatus status() => container.read(exportProvider);
  ExportNotifier exporter() => container.read(exportProvider.notifier);

  ProviderContainer containerWith({
    engine.ExportEngine? exportEngine,
    bool canShare = false,
  }) {
    final created = ProviderContainer.test(
      overrides: [
        fileSharerProvider.overrideWithValue(canShare ? shared.add : null),
        exportEngineProvider.overrideWithValue(exportEngine),
        saveLocationProvider.overrideWithValue((suggestedName) async {
          suggestedNames.add(suggestedName);
          return saveAnswers.removeAt(0);
        }),
        fileOpenerProvider.overrideWithValue(opened.add),
      ],
    );
    created.read(sessionProvider.notifier).addSources([_first, _second]);
    return created;
  }

  setUp(() {
    fake = _FakeEngine();
    saveAnswers = [];
    suggestedNames = [];
    opened = [];
    shared = [];
    container = containerWith(exportEngine: fake);
  });

  test('does nothing when the save dialog is dismissed', () async {
    saveAnswers.add(null);
    await exporter().start();

    expect(status(), isA<ExportIdle>());
    expect(fake.jobs, isEmpty);
  });

  test('is not offered, and does not start, when every file is gone', () async {
    container.read(missingSourcesProvider.notifier).set({
      _first.id,
      _second.id,
    });
    expect(container.read(editorViewStateProvider).canExport, isFalse);

    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    expect(suggestedNames, isEmpty);
    expect(fake.jobs, isEmpty);
  });

  test('is offered while one file is left, named after it', () async {
    container.read(missingSourcesProvider.notifier).set({_first.id});
    expect(container.read(editorViewStateProvider).canExport, isTrue);

    saveAnswers.add(null);
    await exporter().start();
    expect(suggestedNames, ['b-cut.mp4']);
  });

  test('suggests a name after the first clip', () async {
    saveAnswers.add(null);
    await exporter().start();

    expect(suggestedNames, ['beach day-cut.mp4']);
  });

  test('exports the edit to the chosen file, reporting progress', () async {
    saveAnswers.add('D:/out/final.mp4');
    container.read(missingSourcesProvider.notifier).set({_second.id});
    await exporter().start();

    final job = fake.jobs.single;
    expect(job.outputPath, 'D:/out/final.mp4');
    expect(job.editList, same(container.read(sessionProvider).editList));
    expect(job.missingSources, {_second.id});
    expect(status(), isA<ExportRunning>());

    fake.emit(const engine.ExportProgress(0.25));
    await pumpEventQueue();
    expect(status(), isA<ExportRunning>().having((s) => s.progress, '', 0.25));

    await fake.finish(const engine.ExportSucceeded('D:/out/final.mp4'));
    await pumpEventQueue();
    expect(
      status(),
      isA<ExportDone>()
          .having((s) => s.fileName, 'fileName', 'final.mp4')
          .having((s) => s.canShare, 'canShare', false),
    );
  });

  test('adds .mp4 to a name typed without an extension', () async {
    saveAnswers.add('D:/out/final');
    await exporter().start();

    expect(fake.jobs.single.outputPath, 'D:/out/final.mp4');
  });

  Matcher failedWith(ExportProblem problem, {Object? detail}) =>
      isA<ExportFailed>()
          .having((s) => s.problem, 'problem', problem)
          .having((s) => s.detail, 'detail', detail);

  test('reports a failure with the engine output as its detail', () async {
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    await fake.finish(
      const engine.ExportFailed(
        engine.ExportFailure.failed,
        detail: 'Conversion failed!',
      ),
    );
    await pumpEventQueue();

    expect(
      status(),
      failedWith(ExportProblem.failed, detail: 'Conversion failed!'),
    );
  });

  test('tells a known failure by its kind', () async {
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    await fake.finish(
      const engine.ExportFailed(engine.ExportFailure.noEncoder),
    );
    await pumpEventQueue();

    expect(status(), failedWith(ExportProblem.noEncoder));
  });

  test('retries a failed export to the same file without asking', () async {
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    await fake.finish(
      const engine.ExportFailed(engine.ExportFailure.cannotWrite),
    );
    await pumpEventQueue();

    await exporter().retry();
    expect(status(), isA<ExportRunning>());
    expect(suggestedNames, hasLength(1));
    expect(
      [for (final job in fake.jobs) job.outputPath],
      ['D:/out/final.mp4', 'D:/out/final.mp4'],
    );
  });

  test('cancelling stops the engine and returns to rest', () async {
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    fake.emit(const engine.ExportProgress(0.5));
    exporter().cancel();
    await pumpEventQueue();

    expect(status(), isA<ExportIdle>());
  });

  test('says so when ffmpeg is missing, and again on retry', () async {
    container = containerWith();
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    expect(status(), failedWith(ExportProblem.exporterMissing));

    await exporter().retry();
    expect(status(), failedWith(ExportProblem.exporterMissing));
  });

  test('refuses to write over one of the clips', () async {
    saveAnswers.add(_second.path);
    await exporter().start();

    expect(status(), failedWith(ExportProblem.targetIsSource));
    expect(fake.jobs, isEmpty);

    saveAnswers.add('D:/out/final.mp4');
    await exporter().retry();
    expect(suggestedNames, hasLength(2));
    expect(fake.jobs.single.outputPath, 'D:/out/final.mp4');
  });

  test('opens the finished file, and dismissing returns to rest', () async {
    saveAnswers.add('D:/out/final.mp4');
    await exporter().start();
    await fake.finish(const engine.ExportSucceeded('D:/out/final.mp4'));
    await pumpEventQueue();

    exporter().open();
    expect(opened, ['D:/out/final.mp4']);

    exporter().dismiss();
    expect(status(), isA<ExportIdle>());
  });

  group('where the platform saves the export itself (Android)', () {
    const savedUri = 'content://media/external/video/media/99';

    setUp(() async {
      container = containerWith(exportEngine: fake, canShare: true);
      saveAnswers.add('beach day-cut.mp4');
      await exporter().start();
      await fake.finish(
        const engine.ExportSucceeded(
          savedUri,
          displayName: 'beach day-cut (1).mp4',
        ),
      );
      await pumpEventQueue();
    });

    test('names the saved video as the system does and offers Share', () {
      expect(
        status(),
        isA<ExportDone>()
            .having((s) => s.fileName, 'fileName', 'beach day-cut (1).mp4')
            .having((s) => s.canShare, 'canShare', true),
      );
    });

    test('opens and shares the saved video', () {
      exporter()
        ..open()
        ..share();

      expect(opened, [savedUri]);
      expect(shared, [savedUri]);
    });

    test('shares nothing once the outcome is dismissed', () {
      exporter()
        ..dismiss()
        ..share();

      expect(shared, isEmpty);
    });
  });
}
