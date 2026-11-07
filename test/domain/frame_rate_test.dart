import 'package:cutcap/domain/frame_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ntsc = FrameRate(30000, 1001);

  test('one frame at 29.97 fps lasts 33 366 µs', () {
    expect(ntsc.frameDuration, const Duration(microseconds: 33366));
  });

  group('seekTarget', () {
    test('is half a frame before the start of the frame under the time', () {
      // Frame 61 at 30 fps starts at 2.033333 s (ADR 0002 export check).
      const fps30 = FrameRate(30, 1);
      expect(
        fps30.seekTarget(const Duration(microseconds: 2033333)),
        const Duration(microseconds: 2016667),
      );
      expect(
        fps30.seekTarget(const Duration(microseconds: 2050000)),
        const Duration(microseconds: 2016667),
      );
    });

    test('lands between the previous and the target frame at 29.97 fps', () {
      // Frame 1 starts at 33 366 µs; half a frame is 16 683 µs.
      expect(
        ntsc.seekTarget(const Duration(microseconds: 33366)),
        const Duration(microseconds: 16683),
      );
    });

    test('never goes negative on the first frame', () {
      expect(ntsc.seekTarget(const Duration(microseconds: 1)), Duration.zero);
    });
  });
}
