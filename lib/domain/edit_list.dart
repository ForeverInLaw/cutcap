import 'source.dart';

/// Identifies a clip for its whole life, across trims, moves, undo and redo,
/// so the UI can key widgets by it. Assigned by `EditorSession`.
extension type const ClipId(int value) {}

/// A span `[inPoint, outPoint)` of one source, placed on the track.
final class Clip {
  const Clip({
    required this.id,
    required this.sourceId,
    required this.inPoint,
    required this.outPoint,
  }) : assert(inPoint < outPoint);

  final ClipId id;
  final SourceId sourceId;

  /// Source time of the first frame shown.
  final Duration inPoint;

  /// Source time just past the last frame shown.
  final Duration outPoint;

  Duration get duration => outPoint - inPoint;

  /// The same clip with the given fields replaced.
  Clip copyWith({ClipId? id, Duration? inPoint, Duration? outPoint}) => Clip(
    id: id ?? this.id,
    sourceId: sourceId,
    inPoint: inPoint ?? this.inPoint,
    outPoint: outPoint ?? this.outPoint,
  );
}

/// Which end of a clip a trim moves.
enum ClipEdge { inPoint, outPoint }

/// The sequence: clips played back to back, with the sources they cut from.
/// One undo step is one [EditList].
final class EditList {
  const EditList({this.clips = const [], this.sources = const {}});

  /// Sequence order. Unmodifiable when built by `EditorSession`.
  final List<Clip> clips;

  /// Every source a clip refers to (and possibly more).
  final Map<SourceId, Source> sources;

  /// Length of the whole sequence.
  Duration get duration =>
      clips.fold(Duration.zero, (total, clip) => total + clip.duration);

  /// The source [clip] is cut from.
  Source sourceOf(Clip clip) => sources[clip.sourceId]!;

  /// Sequence time at which the clip [id] starts.
  Duration startOf(ClipId id) => _find(id).start;

  /// Sequence time at which the clip [id] shows [sourceTime], which must lie
  /// within the clip. The inverse of [locate].
  Duration sequenceTimeOf(ClipId id, Duration sourceTime) {
    final (:clip, :start) = _find(id);
    if (sourceTime < clip.inPoint || sourceTime > clip.outPoint) {
      throw RangeError('$sourceTime is outside clip $id');
    }
    return start + (sourceTime - clip.inPoint);
  }

  /// What plays at sequence [time], or null outside `[0, duration)`. A time
  /// on a cut belongs to the later clip.
  ClipTime? locate(Duration time) {
    if (time.isNegative) return null;
    for (final (:clip, :start) in _placed) {
      if (time < start + clip.duration) {
        final sourceTime = clip.inPoint + (time - start);
        return (
          clip: clip,
          sourceTime: sourceTime,
          seekTime: sourceOf(clip).frameRate.seekTarget(sourceTime),
        );
      }
    }
    return null;
  }

  /// Each clip with its sequence start time.
  Iterable<({Clip clip, Duration start})> get _placed sync* {
    var start = Duration.zero;
    for (final clip in clips) {
      yield (clip: clip, start: start);
      start += clip.duration;
    }
  }

  ({Clip clip, Duration start}) _find(ClipId id) => _placed.firstWhere(
    (placed) => placed.clip.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'no such clip'),
  );
}

/// A point of the sequence resolved to its clip: [sourceTime] is the source
/// time playing there, and [seekTime] is where to seek the source's player
/// (or `ffmpeg -ss`) to show the frame under it, per ADR 0002.
typedef ClipTime = ({Clip clip, Duration sourceTime, Duration seekTime});
