import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/editor/state/editor_controller.dart';
import 'package:cutcap/editor/state/editor_state.dart';
import 'package:cutcap/media/media_probe.dart';
import 'package:cutcap/player/preview_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../player/fake_preview_player.dart';

Source _source(String name, {int seconds = 4, int fps = 30}) => Source(
  id: SourceId('D:/media/$name'),
  path: 'D:/media/$name',
  duration: Duration(seconds: seconds),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: FrameRate(fps, 1),
  hasAudio: true,
);

final _a = _source('a.mp4');
final _b = _source('b.mp4', seconds: 3, fps: 25);
final _c = _source('c.mp4', seconds: 2);

/// Knows [_a], [_b] and [_c]; any other file is undecodable.
final class _FakeProbe implements MediaProbe {
  @override
  Future<Source> probe(String path) async {
    for (final source in [_a, _b, _c]) {
      if (source.path == path) return source;
    }
    throw UndecodableMedia(path, 'not a video');
  }
}

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  late FakePreviewPlayer player;
  late ProviderContainer container;
  late EditorController editor;

  EditorSession session() => container.read(sessionProvider);
  List<Clip> clips() => session().editList.clips;
  Duration playhead() => container.read(playheadProvider);
  List<String> clipNames() => [
    for (final clip in clips()) session().editList.sourceOf(clip).path,
  ];
  List<(Duration, Duration)> spans() => [
    for (final clip in clips()) (clip.inPoint, clip.outPoint),
  ];

  setUp(() async {
    player = FakePreviewPlayer();
    container = ProviderContainer.test(
      overrides: [
        previewPlayerProvider.overrideWithValue(player as PreviewPlayer),
        mediaProbeProvider.overrideWithValue(_FakeProbe()),
      ],
    );
    editor = container.read(editorControllerProvider);
  });

  Future<void> add(List<Source> sources) async {
    await editor.addFiles([for (final source in sources) source.path]);
    await pumpEventQueue();
  }

  group('adding', () {
    test('appends files in the order given as one undo step', () async {
      await add([_b, _a]);
      await add([_c]);

      expect(clipNames(), [_b.path, _a.path, _c.path]);
      container.read(sessionProvider.notifier).undo();
      expect(clipNames(), [_b.path, _a.path]);
    });

    test('adds what it can and names the files it could not', () async {
      await editor.addFiles([_a.path, 'D:/media/broken.mp4', _b.path]);

      expect(clipNames(), [_a.path, _b.path]);
      expect(container.read(importProblemsProvider), ['broken.mp4']);

      editor.dismissImportProblems();
      expect(container.read(importProblemsProvider), isEmpty);
    });

    test('names a probed file the player then cannot open', () async {
      player.unplayable.add(_a.path);
      await add([_a, _b]);

      expect(clipNames(), [_a.path, _b.path]);
      expect(container.read(importProblemsProvider), ['a.mp4']);
    });

    test('shows the first frame once the track gets its first clip', () async {
      await add([_a]);

      expect(player.calls, ['open ${_a.path}', 'seek 0']);
    });
  });

  group('editing', () {
    test('splits at the playhead and marks the new right part', () async {
      await add([_a]);
      editor.seek(const Duration(seconds: 1));
      editor.split();

      expect(spans(), [
        (Duration.zero, const Duration(seconds: 1)),
        (const Duration(seconds: 1), const Duration(seconds: 4)),
      ]);
      expect(container.read(justEditedProvider), clips().last.id);
    });

    test('deletes the selected clip and closes the gap', () async {
      await add([_a, _b, _c]);
      editor.select(clips()[1].id);
      editor.deleteSelected();

      expect(clipNames(), [_a.path, _c.path]);
      expect(container.read(selectionProvider), isNull);
    });

    test('does nothing on delete without a selection', () async {
      await add([_a, _b]);
      editor.deleteSelected();

      expect(clipNames(), [_a.path, _b.path]);
    });

    test('undoes and redoes edits', () async {
      await add([_a, _b]);
      editor.select(clips().first.id);
      editor.deleteSelected();
      editor.undo();
      expect(clipNames(), [_a.path, _b.path]);

      editor.redo();
      expect(clipNames(), [_b.path]);
    });

    test('keeps the playhead inside a sequence that got shorter', () async {
      await add([_a, _b]);
      editor.seek(const Duration(seconds: 6));
      editor.select(clips().last.id);
      editor.deleteSelected();

      expect(playhead(), _a.duration);
    });

    test('clears the track as one undo step', () async {
      await add([_a, _b]);
      editor.clear();
      expect(clips(), isEmpty);
      expect(playhead(), Duration.zero);

      editor.undo();
      expect(clipNames(), [_a.path, _b.path]);
    });
  });

  group('trimming by drag', () {
    test('is one undo step however many moves it takes', () async {
      await add([_a]);
      final id = clips().single.id;
      editor.beginTrim(id, ClipEdge.outPoint);
      editor.updateTrim(_ms(-500));
      editor.updateTrim(_ms(-1500));
      editor.updateTrim(_ms(-1000));
      editor.endTrim();

      expect(spans(), [(Duration.zero, const Duration(seconds: 3))]);
      expect(container.read(justEditedProvider), id);
      editor.undo();
      expect(spans(), [(Duration.zero, const Duration(seconds: 4))]);
      editor.undo();
      expect(clips(), isEmpty);
    });

    test('snaps to frames and previews the frame under the edge', () async {
      await add([_a]);
      player.calls.clear();
      editor.beginTrim(clips().single.id, ClipEdge.inPoint);
      editor.updateTrim(_ms(1010));
      await pumpEventQueue();

      // 1.01 s snaps to frame 30 (1 s), shown with a seek half a frame early.
      expect(spans(), [(const Duration(seconds: 1), _a.duration)]);
      expect(player.seeks.last, 983334);
    });

    test('previews the last frame kept when trimming the out point', () async {
      await add([_a]);
      player.calls.clear();
      editor.beginTrim(clips().single.id, ClipEdge.outPoint);
      editor.updateTrim(const Duration(seconds: -2));
      await pumpEventQueue();

      // Out at 2 s keeps frames up to 59, which starts at 1 966 666 µs.
      expect(player.seeks.last, 1950000);
    });

    test('records nothing when the edge ends where it started', () async {
      await add([_a]);
      editor.beginTrim(clips().single.id, ClipEdge.inPoint);
      editor.updateTrim(const Duration(seconds: 1));
      editor.updateTrim(Duration.zero);
      editor.endTrim();
      editor.undo();

      expect(clips(), isEmpty);
    });

    test('holds the timeline scale while the edge moves', () async {
      await add([_a, _b]);
      editor.beginTrim(clips().first.id, ClipEdge.outPoint);
      editor.updateTrim(const Duration(seconds: -2));

      expect(container.read(timelineEndProvider), const Duration(seconds: 7));
      editor.endTrim();
      expect(container.read(timelineEndProvider), isNull);
    });
  });

  group('reordering by drag', () {
    test('moves the clip in place as the pointer passes neighbours', () async {
      // a [0, 4 s), b [4 s, 7 s), c [7 s, 9 s).
      await add([_a, _b, _c]);
      final a = clips().first.id;
      editor.beginReorder(a);

      editor.updateReorder(_ms(5000));
      expect(clipNames(), [_a.path, _b.path, _c.path]);

      // Past b's centre (5.5 s) a moves after b ...
      editor.updateReorder(_ms(5600));
      expect(clipNames(), [_b.path, _a.path, _c.path]);

      // ... and stays there until the pointer is back before b's centre,
      // now at 1.5 s.
      editor.updateReorder(_ms(2000));
      expect(clipNames(), [_b.path, _a.path, _c.path]);

      editor.updateReorder(_ms(8500));
      expect(clipNames(), [_b.path, _c.path, _a.path]);
      editor.endReorder();

      expect(container.read(justEditedProvider), a);
      editor.undo();
      expect(clipNames(), [_a.path, _b.path, _c.path]);
    });
  });

  group('transport', () {
    test('steps one frame of the clip under the playhead', () async {
      await add([_a, _b]);
      editor.seek(_ms(3970));

      // In a's last frame (119, from 3 966 666 µs at 30 fps) the next frame
      // is b's first.
      editor.stepFrame(1);
      expect(playhead(), const Duration(seconds: 4));
      editor.stepFrame(1);
      expect(playhead(), _ms(4040));

      editor.stepFrame(-1);
      editor.stepFrame(-1);
      expect(playhead(), const Duration(microseconds: 3966666));
    });

    test('stays inside the sequence when stepping off either end', () async {
      await add([_a]);
      editor.stepFrame(-1);
      expect(playhead(), Duration.zero);

      editor.seek(_a.duration);
      editor.stepFrame(1);
      expect(playhead(), const Duration(microseconds: 3966666));
    });

    test('toggles play and pause and follows the player', () async {
      await add([_a]);
      editor.togglePlay();
      await pumpEventQueue();
      expect(container.read(transportProvider), Transport.forward);

      player.emitPosition(_ms(500));
      expect(playhead(), _ms(500));

      editor.togglePlay();
      await pumpEventQueue();
      expect(container.read(transportProvider), Transport.paused);
      expect(player.calls.last, 'pause');
    });

    test('pauses when the user scrubs or edits', () async {
      await add([_a]);
      editor.togglePlay();
      await pumpEventQueue();
      editor.seek(const Duration(seconds: 2));
      expect(container.read(transportProvider), Transport.paused);

      editor.playForward();
      await pumpEventQueue();
      editor.split();
      expect(container.read(transportProvider), Transport.paused);
    });

    test('returns to paused at the end of the sequence', () async {
      await add([_a]);
      editor.seek(_ms(3900));
      editor.playForward();
      await pumpEventQueue();
      player.emitPosition(const Duration(microseconds: 3966666));
      await pumpEventQueue();

      expect(container.read(transportProvider), Transport.paused);
      expect(playhead(), _a.duration);
    });
  });
}
