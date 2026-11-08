import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/editor/timecode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fps30 = FrameRate(30, 1);

  group('Timecode.full', () {
    test('formats the start of the sequence', () {
      expect(Timecode.full(Duration.zero, fps30), '00:00:00.00');
    });

    test('names the frame whose start time was truncated to microseconds', () {
      // Frame 8 of second 72 at 30 fps starts at 72.2666…s, stored as 72_266_666 µs.
      expect(
        Timecode.full(const Duration(microseconds: 72266666), fps30),
        '00:01:12.08',
      );
    });

    test('keeps showing a frame until the next one starts', () {
      // Frame 1 at 25 fps starts at 40 ms.
      const fps25 = FrameRate(25, 1);
      expect(
        Timecode.full(const Duration(microseconds: 39000), fps25),
        '00:00:00.00',
      );
      expect(
        Timecode.full(const Duration(milliseconds: 40), fps25),
        '00:00:00.01',
      );
    });

    test('never counts past the last frame of a second at 29.97 fps', () {
      expect(
        Timecode.full(
          const Duration(microseconds: 999999),
          const FrameRate(30000, 1001),
        ),
        '00:00:00.29',
      );
    });

    test('carries hours', () {
      expect(
        Timecode.full(const Duration(hours: 1, minutes: 2, seconds: 3), fps30),
        '01:02:03.00',
      );
    });
  });
}
