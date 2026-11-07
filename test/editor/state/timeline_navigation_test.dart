import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/editor/ruler.dart';
import 'package:cutcap/editor/state/editor_controller.dart';
import 'package:cutcap/editor/state/editor_state.dart';
import 'package:cutcap/editor/state/timeline_gestures.dart';
import 'package:cutcap/editor/state/view_state_provider.dart';
import 'package:cutcap/media/media_probe.dart';
import 'package:cutcap/player/preview_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../player/fake_preview_player.dart';

Source _source(String name, {required int seconds}) => Source(
  id: SourceId('D:/media/$name'),
  path: 'D:/media/$name',
  duration: Duration(seconds: seconds),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: true,
);

final _a = _source('a.mp4', seconds: 4);
final _b = _source('b.mp4', seconds: 3);
final _c = _source('c.mp4', seconds: 2);

final class _FakeProbe implements MediaProbe {
  @override
  Future<Source> probe(String path) async =>
      [_a, _b, _c].firstWhere((source) => source.path == path);
}

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

const _frame = Duration(microseconds: 33333);
const _trackWidth = 1200.0;

void main() {
  late FakePreviewPlayer player;
  late ProviderContainer container;
  late EditorController editor;

  Duration playhead() => container.read(playheadProvider);
  TimelineWindow window() =>
      container.read(editorViewStateProvider).visibleWindow;

  setUp(() async {
    player = FakePreviewPlayer();
    container = ProviderContainer.test(
      overrides: [
        previewPlayerProvider.overrideWithValue(player as PreviewPlayer),
        mediaProbeProvider.overrideWithValue(_FakeProbe()),
      ],
    );
    editor = container.read(editorControllerProvider);
    await editor.addFiles([_a.path, _b.path]);
  });

  void zoom(double factor, {double anchor = 0}) =>
      editor.zoomTimeline(factor, anchor, _trackWidth);

  group('snapping', () {
    test('scrubbing close to a cut lands on it', () {
      editor.scrub(_ms(3950), _ms(100));
      expect(playhead(), const Duration(seconds: 4));

      editor.scrub(_ms(60), _ms(100));
      expect(playhead(), Duration.zero);
    });

    test('scrubbing away from a cut goes where the pointer is', () {
      editor.scrub(_ms(3800), _ms(100));
      expect(playhead(), _ms(3800));
    });

    test('frame steps move one frame even next to a cut', () {
      editor.seek(const Duration(microseconds: 3933333));
      editor.stepFrame(1);
      expect(playhead(), const Duration(microseconds: 3966666));
    });
  });

  group('zoom', () {
    test('Ctrl+wheel zooms in down to single frames', () {
      for (var i = 0; i < 100; i++) {
        zoom(0.8, anchor: 0.5);
      }
      final pixelsPerFrame =
          _trackWidth * _frame.inMicroseconds / window().span.inMicroseconds;
      expect(pixelsPerFrame, greaterThanOrEqualTo(100));
      expect(window().span, greaterThan(Duration.zero));
    });

    test('zooming all the way out follows the whole sequence again', () async {
      zoom(0.25);
      expect(window(), TimelineWindow(Duration.zero, _ms(1750)));

      zoom(100);
      await editor.addFiles([_c.path]);
      expect(
        window(),
        const TimelineWindow(Duration.zero, Duration(seconds: 9)),
      );
    });

    test('the wheel scrolls the zoomed track', () {
      zoom(0.25);
      editor.scrollTimeline(_ms(500));
      expect(window(), TimelineWindow(_ms(500), _ms(2250)));
    });

    test('a frame step past the edge turns the page', () {
      zoom(0.25);
      editor.seek(_ms(1740));
      editor.stepFrame(1);
      expect(window().start, playhead());
      expect(playhead(), greaterThanOrEqualTo(_ms(1750)));
    });

    test('playback turns the page as it leaves the track', () async {
      zoom(0.25);
      editor.playForward();
      await pumpEventQueue();
      player.emitPosition(_ms(2000));
      expect(window(), TimelineWindow(_ms(2000), _ms(3750)));
    });

    test('a shorter sequence keeps the zoomed track inside it', () {
      zoom(0.5, anchor: 1);
      editor.seek(_ms(3800));
      expect(window(), TimelineWindow(_ms(3500), _ms(7000)));

      editor.select(container.read(sessionProvider).editList.clips.last.id);
      editor.deleteSelected();
      expect(window(), TimelineWindow(_ms(500), _ms(4000)));
    });
  });
  group('touch', () {
    /// One update of a touch pan or pinch on the track, sent the way the
    /// track sends it.
    void pinch({
      required double fromX,
      required double toX,
      double fromScale = 1,
      double toScale = 1,
    }) {
      final step = TrackPinch.between(
        span: window().span,
        trackWidth: _trackWidth,
        fromX: fromX,
        toX: toX,
        fromScale: fromScale,
        toScale: toScale,
      );
      editor.scrollTimeline(step.scroll);
      editor.zoomTimeline(step.factor, step.anchor, _trackWidth);
    }

    test('spreading two fingers zooms in around them', () {
      pinch(fromX: 600, toX: 600, toScale: 2);
      expect(window(), TimelineWindow(_ms(1750), _ms(5250)));
    });

    test('one finger drags the zoomed track along with it', () {
      zoom(0.25);
      pinch(fromX: 600, toX: 400);
      expect(
        window(),
        const TimelineWindow(
          Duration(microseconds: 291667),
          Duration(microseconds: 2041667),
        ),
      );
    });

    test('the time between the fingers stays under them as they move', () {
      zoom(0.5);
      editor.scrollTimeline(const Duration(seconds: 2));
      pinch(fromX: 300, toX: 600, toScale: 1.25);
      expect(window(), TimelineWindow(_ms(1475), _ms(4275)));
      expect(window().timeAt(600 / _trackWidth), _ms(2875));
    });
  });
  group('dragging on the zoomed track', () {
    test('a move that scrolled the track leaves it where it was dropped', () {
      zoom(0.25);
      final a = container.read(sessionProvider).editList.clips.first.id;
      editor.beginReorder(a);
      editor.scrollTimeline(_ms(5000));
      editor.updateReorder(_ms(6800));
      editor.endReorder();
      expect(window(), TimelineWindow(_ms(5000), _ms(6750)));
      expect(container.read(sessionProvider).editList.clips.last.id, a);
    });

    test('so does a trim', () {
      zoom(0.25);
      final a = container.read(sessionProvider).editList.clips.first.id;
      editor.beginTrim(a, ClipEdge.outPoint);
      editor.scrollTimeline(_ms(2000));
      editor.updateTrim(_ms(-500));
      editor.endTrim();
      expect(window(), TimelineWindow(_ms(2000), _ms(3750)));
    });
  });
}
