import 'dart:async';
import 'dart:io';

import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/editor/state/editor_controller.dart';
import 'package:cutcap/editor/editor_view_state.dart';
import 'package:cutcap/editor/state/editor_state.dart';
import 'package:cutcap/editor/state/view_state_provider.dart';
import 'package:cutcap/export/export_plan.dart';
import 'package:cutcap/media/media_probe.dart';
import 'package:cutcap/player/preview_player.dart';
import 'package:cutcap/session/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../player/fake_preview_player.dart';

Source _source(String name, {int seconds = 4}) => Source(
  id: SourceId('D:/media/$name'),
  path: 'D:/media/$name',
  duration: Duration(seconds: seconds),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: true,
);

final _a = _source('a.mp4');
final _b = _source('b.mp4', seconds: 3);
final _c = _source('c.mp4', seconds: 2);

final class _FakeProbe implements MediaProbe {
  @override
  Future<Source> probe(String path) async =>
      [_a, _b, _c].firstWhere((source) => source.path == path);
}

void main() {
  late Directory dir;
  late File file;
  late FakePreviewPlayer player;
  late Set<String> onDisk;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cutcap_restore_');
    file = File(p.join(dir.path, 'session.json'));
    player = FakePreviewPlayer();
    onDisk = {_a.path, _b.path, _c.path};
  });

  tearDown(() => dir.delete(recursive: true));

  /// A fresh launch of the editor over the same session file, or over
  /// [store].
  ProviderContainer launch({SessionStore? store}) => ProviderContainer.test(
    overrides: [
      previewPlayerProvider.overrideWithValue(player as PreviewPlayer),
      mediaProbeProvider.overrideWithValue(_FakeProbe()),
      sessionStoreProvider.overrideWithValue(
        store ?? SessionStore(() async => file),
      ),
      sourceExistsProvider.overrideWithValue(
        (path) async => onDisk.contains(path),
      ),
    ],
  );

  /// Each clip as (file, in ms, out ms).
  List<(String, int, int)> spans(ProviderContainer container) {
    final list = container.read(sessionProvider).editList;
    return [
      for (final clip in list.clips)
        (
          p.basename(list.sourceOf(clip).path),
          clip.inPoint.inMilliseconds,
          clip.outPoint.inMilliseconds,
        ),
    ];
  }

  /// Launches, adds [_a], [_b], [_c], cuts [_a] at 1 s and quits once the
  /// edits are on disk.
  Future<void> editAndQuit() async {
    final first = launch();
    final editor = first.read(editorControllerProvider);
    await editor.restoreSession();
    await editor.addFiles([_a.path, _b.path, _c.path]);
    editor.seek(const Duration(seconds: 1));
    editor.split();
    await first.read(sessionStoreProvider).flush();
    first.dispose();
  }

  test('restores the last edit on launch', () async {
    await editAndQuit();

    final container = launch();
    await container.read(editorControllerProvider).restoreSession();

    expect(spans(container), [
      ('a.mp4', 0, 1000),
      ('a.mp4', 1000, 4000),
      ('b.mp4', 0, 3000),
      ('c.mp4', 0, 2000),
    ]);
    expect(container.read(sessionProvider).canUndo, isFalse);
    expect(container.read(missingSourcesProvider), isEmpty);
    await pumpEventQueue();
    expect(player.calls.last, 'seek 0');
  });

  test(
    'appends the files the app was opened with to the restored edit',
    () async {
      await editAndQuit();

      final container = launch();
      await container.read(editorControllerProvider).launch([_c.path, _b.path]);

      expect(spans(container), [
        ('a.mp4', 0, 1000),
        ('a.mp4', 1000, 4000),
        ('b.mp4', 0, 3000),
        ('c.mp4', 0, 2000),
        ('c.mp4', 0, 2000),
        ('b.mp4', 0, 3000),
      ]);
      // The append is autosaved; let it land before the folder goes.
      await container.read(sessionStoreProvider).flush();
    },
  );

  test('appends videos shared into the app after the launch files, one '
      'share after the other', () async {
    await editAndQuit();
    final shares = StreamController<List<String>>();
    // Shared while the saved edit is still loading.
    shares.add([_b.path]);

    final container = launch();
    final launched = container.read(editorControllerProvider).launch([
      _c.path,
    ], shared: shares.stream);
    await pumpEventQueue();
    shares.add([_c.path, _a.path]);
    await shares.close();
    await launched;

    expect(spans(container).skip(4), [
      ('c.mp4', 0, 2000),
      ('b.mp4', 0, 3000),
      ('c.mp4', 0, 2000),
      ('a.mp4', 0, 4000),
    ]);
    expect(spans(container).take(2), [
      ('a.mp4', 0, 1000),
      ('a.mp4', 1000, 4000),
    ]);
    await container.read(sessionStoreProvider).flush();
  });

  test('saves every edit as it happens', () async {
    final container = launch();
    final editor = container.read(editorControllerProvider);
    await editor.restoreSession();
    await editor.addFiles([_a.path, _b.path]);
    editor.select(container.read(sessionProvider).editList.clips.first.id);
    editor.deleteSelected();
    await container.read(sessionStoreProvider).flush();

    final saved = (await SessionStore(() async => file).load()).editList!;
    expect(
      [for (final clip in saved.clips) saved.sourceOf(clip).path],
      [_b.path],
    );
  });

  test('a saved edit that cannot be read is kept aside and told', () async {
    await file.writeAsString('{"version": 1, "clips": [');

    final container = launch();
    await container.read(editorControllerProvider).restoreSession();

    expect(spans(container), isEmpty);
    expect(
      container.read(editorViewStateProvider).sessionProblem,
      isA<SessionUnreadable>().having(
        (problem) => problem.keptAs,
        'keptAs',
        startsWith('session.corrupt-'),
      ),
    );
    expect(file.existsSync(), isFalse);
  });

  test('an autosave that fails is told until a later one works', () async {
    // The session file's folder is a file, until the test removes it.
    final blocker = File(p.join(dir.path, 'blocked'))..writeAsStringSync('');
    final container = launch(
      store: SessionStore(() async => File(p.join(blocker.path, 's.json'))),
    );
    final editor = container.read(editorControllerProvider);
    await editor.restoreSession();
    SessionProblem? problem() =>
        container.read(editorViewStateProvider).sessionProblem;

    await editor.addFiles([_a.path]);
    await pumpEventQueue();
    expect(problem(), isA<SessionNotSaved>());

    blocker.deleteSync();
    await editor.addFiles([_b.path]);
    await container.read(sessionStoreProvider).flush();
    await pumpEventQueue();
    expect(problem(), isNull);
  });

  group('a source file that is gone', () {
    test('keeps its clips, flags them and leaves them out of export', () async {
      await editAndQuit();
      onDisk.remove(_b.path);

      final container = launch();
      await container.read(editorControllerProvider).restoreSession();

      expect(spans(container), hasLength(4));
      final missing = container.read(missingSourcesProvider);
      expect(missing, {_b.id});
      final plan = ExportPlan.of(
        container.read(sessionProvider).editList,
        missingSources: missing,
      )!;
      expect(plan.clips.map((clip) => p.basename(clip.path)), [
        'a.mp4',
        'a.mp4',
        'c.mp4',
      ]);
    });

    test('is not opened in the preview', () async {
      await editAndQuit();
      onDisk.remove(_a.path);
      player.calls.clear();

      final container = launch();
      final editor = container.read(editorControllerProvider);
      await editor.restoreSession();
      editor.seek(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(player.calls, ['open ${_b.path}', 'seek 983334']);
    });

    test('is noticed when it disappears or comes back later', () async {
      final container = launch();
      final editor = container.read(editorControllerProvider);
      await editor.restoreSession();
      await editor.addFiles([_a.path, _b.path]);

      onDisk.remove(_a.path);
      await editor.checkSources();
      expect(container.read(missingSourcesProvider), {_a.id});

      onDisk.add(_a.path);
      await editor.checkSources();
      expect(container.read(missingSourcesProvider), isEmpty);
    });
  });
}
