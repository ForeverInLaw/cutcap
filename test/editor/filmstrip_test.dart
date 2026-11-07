import 'package:cutcap/domain/frame_rate.dart';
import 'package:cutcap/editor/filmstrip.dart';
import 'package:flutter_test/flutter_test.dart';

const _fps30 = FrameRate(30, 1);

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  List<int> frames({
    required Duration inPoint,
    required Duration outPoint,
    required Duration cellSpan,
    required int cells,
  }) => [
    for (var i = 0; i < cells; i++)
      Filmstrip.frameFor(
        grid: _fps30,
        inPoint: inPoint,
        outPoint: outPoint,
        cellStart: cellSpan * i,
        cellSpan: cellSpan,
      ),
  ];

  test('samples each cell on a coarse grid that zoom levels share', () {
    // 2 s cells hold 60 frames; their middles fall on the 32-frame grid.
    expect(
      frames(
        inPoint: Duration.zero,
        outPoint: const Duration(seconds: 10),
        cellSpan: const Duration(seconds: 2),
        cells: 5,
      ),
      [0, 64, 128, 192, 256],
    );
  });

  test('shows consecutive frames once a cell spans a single frame', () {
    expect(
      frames(
        inPoint: const Duration(seconds: 1),
        outPoint: const Duration(seconds: 2),
        cellSpan: const Duration(microseconds: 33334),
        cells: 4,
      ),
      [30, 31, 32, 33],
    );
  });

  test('never shows a frame from outside the clip', () {
    expect(
      frames(
        inPoint: _ms(1100),
        outPoint: const Duration(seconds: 3),
        cellSpan: const Duration(seconds: 2),
        cells: 2,
      ),
      // The grid would give frames 32 and 96; the clip holds 33 to 89.
      [33, 89],
    );
  });
}
