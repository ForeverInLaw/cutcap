import 'package:cutcap/domain/edit_list.dart' show ClipId;
import 'package:cutcap/editor/editor_view_state.dart';
import 'package:cutcap/editor/ruler.dart';
import 'package:cutcap/editor/widgets/clip_tile.dart';
import 'package:cutcap/editor/widgets/ruler_view.dart';
import 'package:cutcap/editor/widgets/timeline_view.dart';
import 'package:cutcap/l10n/app_localizations.dart';
import 'package:cutcap/theme/cutcap_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _total = Duration(seconds: 10);
const _touch = PointerDeviceKind.touch;
const _mouse = PointerDeviceKind.mouse;

/// What the track asked the editor to do.
final class _Intents {
  final log = <String>[];
  final scrolls = <Duration>[];
  final zooms = <({double factor, double anchor})>[];
  final scrubs = <({Duration time, Duration tolerance})>[];
  final reorders = <Duration>[];
  final trims = <Duration>[];

  void _note(String entry) => log.add(entry);

  EditorActions actions({
    required ValueChanged<Duration> onScroll,
    required void Function(double factor, double anchor) onZoom,
  }) => EditorActions(
    onAddVideo: () {},
    onExport: () {},
    onPlayPause: () {},
    onStepBackward: () {},
    onStepForward: () {},
    onSplit: () {},
    onDelete: () {},
    onUndo: () {},
    onRedo: () {},
    onSelectClip: (id) => _note('select ${id.value}'),
    onScrub: (time, tolerance) =>
        scrubs.add((time: time, tolerance: tolerance)),
    onZoom: (factor, anchor, _) {
      zooms.add((factor: factor, anchor: anchor));
      onZoom(factor, anchor);
    },
    onScrollTimeline: (delta) {
      scrolls.add(delta);
      onScroll(delta);
    },
    onClear: () {},
    onTrimStart: (id, edge) => _note('trim ${id.value} ${edge.name}'),
    onTrimUpdate: trims.add,
    onTrimEnd: () => _note('trim end'),
    onReorderStart: (id) => _note('move ${id.value}'),
    onReorderUpdate: reorders.add,
    onReorderEnd: () => _note('move end'),
    onDismissUnreadable: () {},
    onCancelExport: () {},
    onOpenExport: () {},
    onShareExport: () {},
    onRetryExport: () {},
    onDismissExport: () {},
  );
}

/// The track over a 10 s sequence of three clips (4 s, 3 s, 3 s), on the
/// phone layout, applying scroll and zoom to its window the way the editor
/// does.
class _Track extends StatefulWidget {
  const _Track(this.intents, {this.window, this.selected});

  final _Intents intents;
  final TimelineWindow? window;
  final int? selected;

  @override
  State<_Track> createState() => _TrackState();
}

class _TrackState extends State<_Track> {
  late TimelineWindow _window =
      widget.window ?? const TimelineWindow(Duration.zero, _total);

  @override
  Widget build(BuildContext context) {
    final state = EditorViewState(
      clips: [
        for (final (i, seconds) in [4, 3, 3].indexed)
          ClipView(
            id: ClipId(i),
            name: 'clip$i.mp4',
            duration: Duration(seconds: seconds),
            isSelected: widget.selected == i,
          ),
      ],
      window: _window,
    );
    return MaterialApp(
      theme: CutcapTheme.data,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: TimelineView(
                state: state,
                compact: true,
                tie: const PlayheadTie(rise: 10, timeWidth: 100),
                actions: widget.intents.actions(
                  onScroll: (delta) => setState(
                    () => _window = _window.scrolledBy(delta, total: _total),
                  ),
                  onZoom: (factor, anchor) => setState(
                    () => _window = _window.zoomedBy(
                      factor,
                      anchor: anchor,
                      total: _total,
                      minSpan: const Duration(milliseconds: 100),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  late _Intents intents;
  late List<MethodCall> platform;

  setUp(() {
    intents = _Intents();
    platform = [];
  });

  Future<void> pumpTrack(
    WidgetTester tester, {
    TimelineWindow? window,
    int? selected,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platform.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      _Track(intents, window: window, selected: selected),
    );
  }

  Rect tile(WidgetTester tester, int index) =>
      tester.getRect(find.byType(ClipTile).at(index));

  /// The film of a tile, below its label.
  Offset film(WidgetTester tester, int index) =>
      tile(tester, index).bottomCenter - const Offset(0, 30);

  group('touch', () {
    testWidgets('a long press lifts a clip to move it', (tester) async {
      await pumpTrack(tester);
      final gesture = await tester.startGesture(film(tester, 0), kind: _touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(intents.log, ['select 0', 'move 0']);
      expect(
        platform.map((call) => call.method),
        contains('HapticFeedback.vibrate'),
      );

      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      expect(intents.log, ['select 0', 'move 0', 'move end']);
      expect(intents.reorders, isNotEmpty);
      expect(intents.reorders.last, greaterThan(const Duration(seconds: 4)));
    });

    testWidgets('a quick drag across clips scrolls the zoomed track', (
      tester,
    ) async {
      const window = TimelineWindow(Duration(seconds: 2), Duration(seconds: 6));
      await pumpTrack(tester, window: window);
      final gesture = await tester.startGesture(film(tester, 1), kind: _touch);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      expect(intents.log, isEmpty);
      final scrolled = intents.scrolls.fold(Duration.zero, (a, b) => a + b);
      expect(scrolled, lessThan(Duration.zero));
    });

    testWidgets('a flick keeps the track gliding after the finger lifts', (
      tester,
    ) async {
      const window = TimelineWindow(Duration(seconds: 4), Duration(seconds: 6));
      await pumpTrack(tester, window: window);
      await tester.flingFrom(
        film(tester, 0),
        const Offset(-150, 0),
        1500,
        deviceKind: _touch,
      );
      final whileTouching = intents.scrolls.length;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(intents.scrolls.length, greaterThan(whileTouching));
      expect(intents.scrolls.last, greaterThan(Duration.zero));
      await tester.pumpAndSettle();
    });

    testWidgets('pinching zooms in around the fingers', (tester) async {
      await pumpTrack(tester);
      final centre = film(tester, 1);
      final left = await tester.startGesture(
        centre - const Offset(30, 0),
        kind: _touch,
        pointer: 1,
      );
      final right = await tester.startGesture(
        centre + const Offset(30, 0),
        kind: _touch,
        pointer: 2,
      );
      for (var i = 0; i < 6; i++) {
        await left.moveBy(const Offset(-5, 0));
        await right.moveBy(const Offset(5, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();

      expect(intents.log, isEmpty);
      final factor = intents.zooms.fold(1.0, (a, b) => a * b.factor);
      expect(factor, closeTo(0.5, 0.05));
      final track = tester.getRect(find.byType(RulerView).first);
      expect(
        intents.zooms.last.anchor,
        closeTo((centre.dx - track.left) / track.width, 0.01),
      );
    });

    testWidgets('a tap selects the clip', (tester) async {
      await pumpTrack(tester);
      await tester.tapAt(film(tester, 2), kind: _touch);
      expect(intents.log, ['select 2']);
    });

    testWidgets('the selected clip trims from a finger beside its edge', (
      tester,
    ) async {
      await pumpTrack(tester, selected: 0);
      // Past the end of the clip, over the gutter and the next clip.
      final outside = Offset(tile(tester, 0).right + 16, film(tester, 0).dy);
      final gesture = await tester.startGesture(outside, kind: _touch);
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();

      expect(intents.log, ['trim 0 outPoint', 'trim end']);
      expect(intents.trims.last, greaterThan(Duration.zero));
    });

    testWidgets('an unselected clip edge does not trim under a finger', (
      tester,
    ) async {
      await pumpTrack(tester, selected: 0);
      final edge = Offset(tile(tester, 2).left + 3, film(tester, 2).dy);
      final gesture = await tester.startGesture(edge, kind: _touch);
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.up();
      expect(intents.log, isEmpty);
    });

    testWidgets('scrubbing snaps from further away than with a mouse', (
      tester,
    ) async {
      await pumpTrack(tester);
      final ruler = tester.getRect(find.byType(RulerView).first);
      await tester.tapAt(ruler.center, kind: _touch);
      await tester.tapAt(ruler.center, kind: _mouse);
      final [finger, mouse] = intents.scrubs;
      expect(finger.time, mouse.time);
      expect(
        finger.tolerance.inMicroseconds,
        closeTo(mouse.tolerance.inMicroseconds * 2, 1),
      );
    });
  });

  group('mouse', () {
    testWidgets('a drag moves the clip at once', (tester) async {
      await pumpTrack(tester);
      final gesture = await tester.startGesture(film(tester, 0), kind: _mouse);
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      expect(intents.log, ['move 0', 'move end']);
      expect(intents.scrolls, isEmpty);
    });

    testWidgets('any clip trims at its edge', (tester) async {
      await pumpTrack(tester);
      final edge = Offset(tile(tester, 1).left + 3, film(tester, 1).dy);
      final gesture = await tester.startGesture(edge, kind: _mouse);
      await gesture.moveBy(const Offset(40, 0));
      await gesture.up();
      expect(intents.log, ['trim 1 inPoint', 'trim end']);
    });
  });

  group('dragging near an end of the zoomed track', () {
    const window = TimelineWindow(Duration(seconds: 2), Duration(seconds: 5));

    testWidgets('scrolls it and keeps moving the clip', (tester) async {
      await pumpTrack(tester, window: window);
      final track = tester.getRect(find.byType(RulerView).first);
      final gesture = await tester.startGesture(film(tester, 1), kind: _mouse);
      await gesture.moveTo(Offset(track.right - 4, film(tester, 1).dy));
      final reached = intents.reorders.last;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(intents.scrolls, isNotEmpty);
      expect(intents.scrolls.every((d) => d > Duration.zero), isTrue);
      expect(intents.reorders.last, greaterThan(reached));

      await gesture.up();
      final settled = intents.scrolls.length;
      await tester.pump(const Duration(milliseconds: 100));
      expect(intents.scrolls.length, settled);
    });

    testWidgets('scrolls it while a finger trims', (tester) async {
      await pumpTrack(tester, window: window, selected: 0);
      final track = tester.getRect(find.byType(RulerView).first);
      final edge = Offset(tile(tester, 0).right, film(tester, 0).dy);
      final gesture = await tester.startGesture(edge, kind: _touch);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveTo(Offset(track.right, edge.dy));
      final reached = intents.trims.last;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      expect(intents.log, ['trim 0 outPoint', 'trim end']);
      expect(intents.scrolls, isNotEmpty);
      expect(intents.trims.last, greaterThan(reached));
    });
  });
}
