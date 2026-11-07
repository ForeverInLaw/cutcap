import 'package:cutcap/editor/state/timeline_gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('edge scroll while dragging', () {
    const width = 600.0;
    double rate(double x) => EdgeScroll.rate(x, trackWidth: width);

    test('holds still away from the ends', () {
      expect(rate(300), 0);
      expect(rate(EdgeScroll.zone), 0);
      expect(rate(width - EdgeScroll.zone), 0);
    });

    test('speeds up towards either end, back on the left', () {
      expect(rate(EdgeScroll.zone / 2), -EdgeScroll.maxRate / 2);
      expect(rate(width - EdgeScroll.zone / 2), EdgeScroll.maxRate / 2);
      expect(rate(0), -EdgeScroll.maxRate);
      expect(rate(width), EdgeScroll.maxRate);
    });

    test('keeps full speed past the ends', () {
      expect(rate(-80), -EdgeScroll.maxRate);
      expect(rate(width + 80), EdgeScroll.maxRate);
    });

    test('narrows the zones on a short track', () {
      expect(EdgeScroll.rate(30, trackWidth: 120), 0);
      expect(EdgeScroll.rate(15, trackWidth: 120), -EdgeScroll.maxRate / 2);
    });
  });
}
