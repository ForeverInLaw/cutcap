import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/player/sequence_playback.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_preview_player.dart';

final _a = Source(
  id: SourceId('a'),
  path: 'a.mp4',
  duration: Duration(seconds: 4),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: FrameRate(30, 1),
  hasAudio: true,
);

final _b = Source(
  id: SourceId('b'),
  path: 'b.mp4',
  duration: Duration(seconds: 3),
  resolution: (width: 960, height: 540),
  rotation: 90,
  frameRate: FrameRate(25, 1),
  hasAudio: false,
);

Duration _us(int microseconds) => Duration(microseconds: microseconds);
Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  late FakePreviewPlayer player;
  late SequencePlayback playback;
  late List<Duration> positions;
  late int ended;

  // A[0, 4 s) at 30 fps, then B[0, 3 s) at 25 fps from sequence time 4 s.
  final ab = const EditorSession().addSources([_a, _b]).editList;

  setUp(() {
    player = FakePreviewPlayer();
    positions = [];
    ended = 0;
    playback = SequencePlayback(
      player,
      onPosition: positions.add,
      onEnded: () => ended++,
    );
  });

  tearDown(() => playback.dispose());

  group('show', () {
    test('opens the source under the time and seeks to its frame', () async {
      playback.show(ab, const Duration(seconds: 1));
      await pumpEventQueue();

      // Frame 30 starts at 1 s; seek half a frame (16 666 µs) before it.
      expect(player.calls, ['open a.mp4', 'seek 983334']);
    });

    test('maps time in a later clip to its own source', () async {
      playback.show(ab, _ms(4500));
      await pumpEventQueue();

      // 0.5 s into B falls in frame 12 (from 480 ms at 25 fps); half a frame
      // is 20 000 µs.
      expect(player.calls, ['open b.mp4', 'seek 460000']);
    });

    test('seeks without reopening a source that is already open', () async {
      playback.show(ab, const Duration(seconds: 1));
      playback.show(ab, const Duration(seconds: 2));
      await pumpEventQueue();

      expect(player.calls, ['open a.mp4', 'seek 983334', 'seek 1983334']);
    });

    test('drops intermediate seeks while one is in flight', () async {
      player.holdSeeks = true;
      playback.show(ab, const Duration(seconds: 1));
      await pumpEventQueue();
      playback.show(ab, const Duration(seconds: 2));
      playback.show(ab, const Duration(seconds: 3));
      player.releaseSeek();
      await pumpEventQueue();

      expect(player.seeks, [983334, 2983334]);
    });

    test('shows a frame of a source directly', () async {
      playback.showSource(_b, const Duration(seconds: 1));
      await pumpEventQueue();

      expect(player.calls, ['open b.mp4', 'seek 980000']);
    });
  });

  group('play', () {
    test('starts at the playhead and reports sequence time', () async {
      await playback.play(ab, _ms(4500));
      await pumpEventQueue();
      player.emitPosition(_ms(600));

      expect(player.calls, ['open b.mp4', 'seek 460000', 'play']);
      expect(positions, [_ms(4600)]);
    });

    test('moves on to the next clip at the last frame of a clip', () async {
      await playback.play(ab, _ms(3900));
      await pumpEventQueue();
      player.calls.clear();

      // Frame 119, A's last, starts at 3 966 666 µs.
      player.emitPosition(_us(3966666));
      await pumpEventQueue();
      player.emitPosition(_ms(40));

      expect(player.calls, ['pause', 'open b.mp4', 'seek 0', 'play']);
      expect(positions.last, _ms(4040));
      expect(ended, 0);
    });

    test('plays through a split without touching the player', () async {
      final split = const EditorSession()
          .addSources([_a])
          .split(const Duration(seconds: 2))
          .editList;
      await playback.play(split, _ms(1900));
      await pumpEventQueue();
      player.calls.clear();

      player.emitPosition(_us(1966666));
      player.emitPosition(_ms(2100));

      expect(player.calls, isEmpty);
      expect(positions.last, _ms(2100));
    });

    test('ignores stale positions from before a jump', () async {
      // A[2 s, 4 s) plays first, then A[0, 2 s).
      var session = const EditorSession()
          .addSources([_a])
          .split(const Duration(seconds: 2));
      session = session.move(session.editList.clips.last.id, 0);
      await playback.play(session.editList, Duration.zero);
      await pumpEventQueue();

      player.emitPosition(_us(3966666));
      await pumpEventQueue();
      positions.clear();
      player.calls.clear();
      player.emitPosition(_us(3983000));
      player.emitPosition(_ms(100));

      expect(player.calls, isEmpty);
      expect(positions, [_ms(2100)]);
    });

    test('pauses at the end of the sequence and reports it', () async {
      await playback.play(ab, _ms(6900));
      await pumpEventQueue();
      player.calls.clear();

      // B's last frame, 74, starts at 2.96 s.
      player.emitPosition(_ms(2960));
      await pumpEventQueue();

      expect(player.calls, ['pause']);
      expect(positions.last, const Duration(seconds: 7));
      expect(ended, 1);
    });

    test('treats the end of a file as the end of its clip', () async {
      await playback.play(ab, _ms(6900));
      await pumpEventQueue();

      player.emitCompleted();
      await pumpEventQueue();

      expect(ended, 1);
    });

    test('starts over from the beginning at the end of the sequence', () async {
      await playback.play(ab, ab.duration);
      await pumpEventQueue();

      expect(player.calls, ['open a.mp4', 'seek 0', 'play']);
    });

    test('stops reporting once paused', () async {
      await playback.play(ab, _ms(500));
      await pumpEventQueue();
      await playback.pause();
      player.emitPosition(_ms(600));

      expect(player.calls.last, 'pause');
      expect(positions, isEmpty);
    });
  });

  group('reverse', () {
    test('moves the playhead back in real time and stops at 0', () {
      fakeAsync((async) {
        playback.reverse(ab, _ms(100));
        async.elapse(_ms(40));
        expect(positions, [_ms(60)]);

        async.elapse(_ms(200));
        expect(positions.last, Duration.zero);
        expect(ended, 1);

        final count = positions.length;
        async.elapse(_ms(200));
        expect(positions, hasLength(count));
      });
    });

    test('stops when paused', () {
      fakeAsync((async) {
        playback.reverse(ab, const Duration(seconds: 1));
        async.elapse(_ms(80));
        playback.pause();
        final count = positions.length;
        async.elapse(_ms(400));

        expect(positions, hasLength(count));
        expect(ended, 0);
      });
    });
  });
}
