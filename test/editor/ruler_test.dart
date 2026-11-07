import 'package:cutcap/editor/ruler.dart';
import 'package:cutcap/editor/timecode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fps30 = FrameRate(30, 1);

  group('TimelineWindow', () {
    const window = TimelineWindow(Duration(seconds: 10), Duration(seconds: 20));

    test('maps a position across the track to a time inside the window', () {
      expect(window.timeAt(0.25), const Duration(milliseconds: 12500));
      expect(window.fractionOf(const Duration(seconds: 15)), 0.5);
    });

    test('clamps positions dragged past either end', () {
      expect(window.timeAt(-0.3), const Duration(seconds: 10));
      expect(window.timeAt(1.7), const Duration(seconds: 20));
    });
  });

  group('Ruler', () {
    // The sketch's sequence: 3:40 fitted into a 1376 px wide track.
    const whole = TimelineWindow(
      Duration.zero,
      Duration(minutes: 3, seconds: 40),
    );

    test('labels every 30 s, leaving the ends to the guide words', () {
      final ticks = Ruler.ticks(whole, width: 1376, rate: fps30);

      expect(ticks.where((tick) => tick.labelled).map((tick) => tick.time), [
        for (var s = 30; s <= 180; s += 30) Duration(seconds: s),
      ]);
    });

    test('drops a label that would run into the closing guide word', () {
      // On a phone the 2:00 tick lands 167 px into a 306 px ruler; its label
      // would reach the guide word naming 3:40 at the right edge.
      final ticks = Ruler.ticks(whole, width: 306, rate: fps30);

      expect(ticks.where((tick) => tick.labelled), isEmpty);
    });

    test('fills the gaps with the finest minor step that stays legible', () {
      // 6.25 px per second: 1 s would crowd to 6 px, 2 s gives 12.5 px.
      final ticks = Ruler.ticks(whole, width: 1376, rate: fps30);

      expect(ticks.take(3).map((tick) => (tick.time, tick.major)), [
        (const Duration(seconds: 2), false),
        (const Duration(seconds: 4), false),
        (const Duration(seconds: 6), false),
      ]);
      expect(ticks.last, (
        time: const Duration(minutes: 3, seconds: 40),
        major: false,
        labelled: false,
      ));
    });

    test('zoomed in, steps by whole frames and marks every frame', () {
      // 2 s across 1000 px at 30 fps: one frame is 16.7 px.
      const close = TimelineWindow(Duration.zero, Duration(seconds: 2));
      final ticks = Ruler.ticks(close, width: 1000, rate: fps30);

      expect(ticks.first.time, const Duration(microseconds: 33333));
      expect(
        ticks.where((tick) => tick.labelled).map((tick) => tick.time),
        const [
          Duration(microseconds: 333333),
          Duration(microseconds: 666666),
          Duration(seconds: 1),
          Duration(microseconds: 1333333),
          // 1.67 s sits within two label widths of the closing guide word.
        ],
      );
    });
  });
}
