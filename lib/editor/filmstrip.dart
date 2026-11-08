import '../domain/frame_rate.dart';

/// Which source frame each filmstrip cell shows.
abstract final class Filmstrip {
  /// The frame (index on [grid]) for the cell that starts [cellStart] into
  /// a clip of `[inPoint, outPoint)` when each cell spans [cellSpan] of
  /// clip time.
  ///
  /// It is the frame at the cell's middle, rounded down to a multiple of the
  /// largest power of two of frames that fits in a cell. Zoom levels then
  /// share most of their frames, so zooming in or out mostly reuses cached
  /// thumbnails; once a cell spans one frame, every frame shows. Frames
  /// outside the clip are pulled back to its first or last frame.
  static int frameFor({
    required FrameRate grid,
    required Duration inPoint,
    required Duration outPoint,
    required Duration cellStart,
    required Duration cellSpan,
  }) {
    final middle = grid.frameAt(inPoint + cellStart + cellSpan ~/ 2);
    final framesPerCell =
        cellSpan.inMicroseconds / grid.frameDuration.inMicroseconds;
    var step = 1;
    while (step * 2 <= framesPerCell) {
      step *= 2;
    }
    final first = grid.frameAt(inPoint);
    final last = grid.frameAt(outPoint - const Duration(microseconds: 1));
    return (middle ~/ step * step).clamp(first, last);
  }
}
