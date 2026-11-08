import 'package:cutcap/domain/editor_session.dart';
import 'package:flutter_test/flutter_test.dart';

const fps30 = FrameRate(30, 1);
const ntsc = FrameRate(30000, 1001);

Duration us(int microseconds) => Duration(microseconds: microseconds);

Source source(
  String id, {
  Duration duration = const Duration(seconds: 10),
  FrameRate rate = fps30,
}) => Source(
  id: SourceId(id),
  path: 'C:/videos/$id.mp4',
  duration: duration,
  resolution: (width: 1920, height: 1080),
  rotation: 0,
  frameRate: rate,
  hasAudio: true,
);

/// Each clip as (source id, in, out) in microseconds.
List<(String, int, int)> spans(EditorSession session) => [
  for (final clip in session.editList.clips)
    (
      clip.sourceId.value,
      clip.inPoint.inMicroseconds,
      clip.outPoint.inMicroseconds,
    ),
];

void main() {
  group('addSources', () {
    test('appends one whole-source clip per source, in the given order', () {
      final session = const EditorSession()
          .addSources([source('a', duration: const Duration(seconds: 4))])
          .addSources([
            source('b', duration: const Duration(seconds: 2)),
            source('c', duration: const Duration(seconds: 3)),
          ]);

      expect(spans(session), [
        ('a', 0, 4000000),
        ('b', 0, 2000000),
        ('c', 0, 3000000),
      ]);
      expect(session.editList.duration, const Duration(seconds: 9));
    });
  });

  group('split', () {
    final twoClips = const EditorSession().addSources([
      source('a', duration: const Duration(seconds: 2)),
      source('b', rate: ntsc),
    ]);

    test(
      'cuts at the start of the frame under the time, on its source grid',
      () {
        // 3 s in the sequence is 1 s into b; at 29.97 fps that is frame 29,
        // which starts at 29 · 1001 / 30000 s = 967 633.3 µs.
        final session = twoClips.split(const Duration(seconds: 3));

        expect(spans(session), [
          ('a', 0, 2000000),
          ('b', 0, 967633),
          ('b', 967633, 10000000),
        ]);
        expect(session.editList.duration, twoClips.editList.duration);
      },
    );

    test(
      'keeps the id on the left part and gives the right part a new one',
      () {
        final before = twoClips.editList.clips.map((c) => c.id).toList();
        final after = twoClips
            .split(const Duration(seconds: 3))
            .editList
            .clips
            .map((c) => c.id)
            .toList();

        expect(after.take(2), before);
        expect(before, isNot(contains(after[2])));
      },
    );

    test('is rejected where a part would be empty or outside the sequence', () {
      for (final time in [
        const Duration(seconds: 2), // on the cut between a and b
        const Duration(seconds: 2, milliseconds: 20), // inside b's first frame
        const Duration(seconds: 12), // the end of the sequence
        const Duration(seconds: -1),
      ]) {
        expect(twoClips.split(time), same(twoClips), reason: '$time');
      }
    });
  });

  final abc = const EditorSession().addSources([
    source('a', duration: const Duration(seconds: 1)),
    source('b', duration: const Duration(seconds: 2)),
    source('c', duration: const Duration(seconds: 3)),
  ]);
  ClipId idOf(EditorSession session, int index) =>
      session.editList.clips[index].id;

  group('remove', () {
    test('closes the gap: later clips move up by the removed length', () {
      final c = idOf(abc, 2);
      final session = abc.remove(idOf(abc, 1));

      expect(spans(session), [('a', 0, 1000000), ('c', 0, 3000000)]);
      expect(session.editList.duration, const Duration(seconds: 4));
      expect(session.editList.startOf(c), const Duration(seconds: 1));
    });
  });

  group('move', () {
    List<String> order(EditorSession session) => [
      for (final (id, _, _) in spans(session)) id,
    ];

    test('puts the clip at the index it will have afterwards', () {
      expect(order(abc.move(idOf(abc, 0), 2)), ['b', 'c', 'a']);
      expect(order(abc.move(idOf(abc, 2), 0)), ['c', 'a', 'b']);
    });

    test('clamps the index to the track', () {
      expect(order(abc.move(idOf(abc, 0), 9)), ['b', 'c', 'a']);
      expect(order(abc.move(idOf(abc, 2), -1)), ['c', 'a', 'b']);
    });

    test('to where the clip already is changes nothing', () {
      expect(abc.move(idOf(abc, 1), 1), same(abc));
    });
  });

  group('undo and redo', () {
    test('step back through every edit and forward again', () {
      final split = abc.split(const Duration(milliseconds: 1500));
      final removed = split.remove(idOf(split, 0));

      final undone = removed.undo().undo().undo();
      expect(spans(undone), isEmpty);
      expect((undone.canUndo, undone.canRedo), (false, true));
      expect(spans(undone.redo()), spans(abc));
      expect(spans(undone.redo().redo()), spans(split));

      final redone = undone.redo().redo().redo();
      expect(spans(redone), spans(removed));
      expect((redone.canUndo, redone.canRedo), (true, false));
    });

    test('a new edit after undo drops what could be redone', () {
      final session = abc.remove(idOf(abc, 0)).undo().remove(idOf(abc, 2));

      expect(session.canRedo, isFalse);
      expect(spans(session.undo()), spans(abc));
    });

    test('with nothing to undo or redo change nothing', () {
      expect(const EditorSession().undo(), same(const EditorSession()));
      expect(abc.redo(), same(abc));
    });

    test('never hand out a clip id again after undo', () {
      final first = abc.split(const Duration(milliseconds: 1500));
      final again = first.undo().split(const Duration(milliseconds: 1500));

      expect(idOf(again, 2), isNot(idOf(first, 2)));
    });
  });

  group('clear', () {
    test('empties the sequence as one undoable step', () {
      final cleared = abc.clear();

      expect(spans(cleared), isEmpty);
      expect(cleared.editList.duration, Duration.zero);
      expect(spans(cleared.undo()), spans(abc));
    });

    test('on an empty sequence changes nothing', () {
      final empty = abc.clear();
      expect(empty.clear(), same(empty));
    });
  });

  group('mapping', () {
    // a: 2 s at 30 fps, then n at 29.97 fps trimmed to start on frame 30
    // (1 001 000 µs).
    final added = const EditorSession().addSources([
      source('a', duration: const Duration(seconds: 2)),
      source('n', rate: ntsc),
    ]);
    final n = idOf(added, 1);
    final edit = added.trim(n, ClipEdge.inPoint, us(1001000)).editList;

    test('finds the clip and source time under a sequence time', () {
      final hit = edit.locate(us(2500000))!;

      expect(hit.clip.id, n);
      expect(hit.sourceTime, us(1501000));
      expect(edit.startOf(n), const Duration(seconds: 2));
      expect(edit.sequenceTimeOf(n, us(1501000)), us(2500000));
    });

    test('gives a cut to the later clip and nothing past the end', () {
      expect(edit.locate(const Duration(seconds: 2))!.clip.id, n);
      expect(edit.locate(edit.duration), isNull);
    });

    test('seeks half a frame before the start of the frame shown', () {
      // Frame 30 starts at 1 001 000 µs; half a 29.97 frame is 16 683 µs.
      expect(edit.locate(us(2000000))!.seekTime, us(984317));
      expect(edit.locate(us(2020000))!.seekTime, us(984317));
    });
  });

  group('trim', () {
    // One 10 s clip at 29.97 fps. Frame k starts at k · 1001 / 30000 s:
    // 29 → 967 633, 30 → 1 001 000, 31 → 1 034 366, 149 → 4 971 633,
    // 150 → 5 005 000 µs. 10 s falls inside frame 299, so the source ends
    // on a partial frame.
    final ntscClip = const EditorSession().addSources([
      source('n', rate: ntsc),
    ]);
    final id = idOf(ntscClip, 0);
    EditorSession trimmed(
      ClipEdge edge,
      int microseconds, {
      EditorSession? on,
    }) => (on ?? ntscClip).trim(id, edge, us(microseconds));

    test('snaps the edge to the nearest frame boundary of the source', () {
      expect(spans(trimmed(ClipEdge.inPoint, 1000000)), [
        ('n', 1001000, 10000000),
      ]);
      expect(spans(trimmed(ClipEdge.inPoint, 980000)), [
        ('n', 967633, 10000000),
      ]);
      expect(spans(trimmed(ClipEdge.outPoint, 5000000)), [('n', 0, 5005000)]);
    });

    test('stops at the start and the end of the source', () {
      final shortened = trimmed(ClipEdge.outPoint, 5000000);
      final extended = trimmed(ClipEdge.outPoint, 11000000, on: shortened);
      final opened = trimmed(
        ClipEdge.inPoint,
        -500000,
        on: trimmed(ClipEdge.inPoint, 1000000),
      );

      expect(spans(extended), [('n', 0, 10000000)]);
      expect(spans(opened), [('n', 0, 10000000)]);
    });

    test('keeps at least one frame', () {
      final shortened = trimmed(ClipEdge.outPoint, 5000000);
      final late = trimmed(ClipEdge.inPoint, 1001000);

      expect(spans(trimmed(ClipEdge.inPoint, 6000000, on: shortened)), [
        ('n', 4971633, 5005000),
      ]);
      expect(spans(trimmed(ClipEdge.outPoint, 0, on: late)), [
        ('n', 1001000, 1034366),
      ]);
    });

    test('to where the edge already snaps changes nothing', () {
      expect(trimmed(ClipEdge.inPoint, 10000), same(ntscClip));
      expect(trimmed(ClipEdge.outPoint, 10000000), same(ntscClip));
    });
  });
}
