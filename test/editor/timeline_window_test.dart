import 'package:cutcap/editor/ruler.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

TimelineWindow _window(int startMs, int endMs) =>
    TimelineWindow(_ms(startMs), _ms(endMs));

void main() {
  const total = Duration(seconds: 10);
  const minSpan = Duration(milliseconds: 100);

  group('zoomedBy', () {
    TimelineWindow zoom(TimelineWindow window, double factor, double anchor) =>
        window.zoomedBy(factor, anchor: anchor, total: total, minSpan: minSpan);

    test('keeps the time under the cursor where it is', () {
      // 2.5 s sits a quarter of the way in, before and after.
      expect(zoom(_window(0, 10000), 0.5, 0.25), _window(1250, 6250));
    });

    test('stops at the whole sequence when zooming out', () {
      expect(zoom(_window(2000, 4000), 8, 0.5), _window(0, 10000));
    });

    test('stops at the smallest span when zooming in', () {
      expect(zoom(_window(0, 10000), 0.0001, 0.5), _window(4950, 5050));
    });

    test('stays inside the sequence when zooming out near an end', () {
      expect(zoom(_window(8000, 10000), 2, 0.9), _window(6000, 10000));
      expect(zoom(_window(0, 2000), 2, 0.1), _window(0, 4000));
    });
  });

  group('scrolledBy', () {
    test('moves the window by the given time', () {
      expect(
        _window(1000, 3000).scrolledBy(_ms(500), total: total),
        _window(1500, 3500),
      );
    });

    test('stops at either end of the sequence', () {
      expect(
        _window(1000, 3000).scrolledBy(_ms(-5000), total: total),
        _window(0, 2000),
      );
      expect(
        _window(7000, 9000).scrolledBy(_ms(5000), total: total),
        _window(8000, 10000),
      );
    });
  });

  group('revealing', () {
    final window = _window(2000, 4000);

    test('stays put while the time is in view', () {
      expect(window.revealing(_ms(3999), total: total), same(window));
    });

    test('turns a page forward to start at a time past its end', () {
      expect(window.revealing(_ms(4000), total: total), _window(4000, 6000));
      expect(window.revealing(_ms(9500), total: total), _window(8000, 10000));
    });

    test('turns a page back to end at a time before its start', () {
      expect(window.revealing(_ms(1960), total: total), _window(0, 2000));
    });
  });

  group('within', () {
    test('slides back inside a sequence that got shorter', () {
      expect(
        _window(6000, 9000).within(const Duration(seconds: 8)),
        _window(5000, 8000),
      );
    });

    test('becomes the whole sequence once that is shorter than the span', () {
      expect(_window(6000, 9000).within(_ms(2500)), _window(0, 2500));
    });
  });
}
