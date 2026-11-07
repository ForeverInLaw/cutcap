import 'dart:math' as math;

import 'edit_list.dart';
import 'source.dart';

export 'edit_list.dart';
export 'frame_rate.dart';
export 'source.dart';

/// An editing session: the current [EditList] plus its undo history.
///
/// Immutable. Every command returns the session after it; a command that
/// changes nothing returns this same instance and records no undo step.
/// Commands take user input as given and reject or clamp it as documented;
/// an unknown [ClipId] is a programming error and throws [ArgumentError].
final class EditorSession {
  /// An empty session.
  const EditorSession() : this._(const EditList(), const [], const [], 0);

  /// A session continuing [editList] as saved earlier: no undo history, and
  /// new clips get ids above the ones already in it.
  EditorSession.restored(EditList editList)
    : this._(
        editList,
        const [],
        const [],
        editList.clips.fold(
          0,
          (next, clip) => math.max(next, clip.id.value + 1),
        ),
      );

  const EditorSession._(this.editList, this._undo, this._redo, this._nextId);

  /// What is being edited now.
  final EditList editList;

  final List<EditList> _undo;
  final List<EditList> _redo;

  /// Next unused [ClipId]; never reused, not even after undo.
  final int _nextId;

  /// Appends one whole-source clip per source, in the given order.
  EditorSession addSources(Iterable<Source> sources) {
    final added = sources.toList();
    if (added.isEmpty) return this;
    var nextId = _nextId;
    return _commit(
      EditList(
        clips: List.unmodifiable([
          ...editList.clips,
          for (final source in added)
            Clip(
              id: ClipId(nextId++),
              sourceId: source.id,
              inPoint: Duration.zero,
              outPoint: source.duration,
            ),
        ]),
        sources: Map.unmodifiable({
          ...editList.sources,
          for (final source in added) source.id: source,
        }),
      ),
      nextId: nextId,
    );
  }

  /// Cuts the clip under sequence [time] in two at the start of the frame
  /// under it, so that frame opens the right-hand clip. The left part keeps
  /// the clip's id. Rejected (no change) on a cut or inside a clip's first
  /// frame, where one part would be empty, and outside the sequence.
  EditorSession split(Duration time) {
    final hit = editList.locate(time);
    if (hit == null) return this;
    final clip = hit.clip;
    final grid = editList.sourceOf(clip).frameRate;
    final cut = grid.frameStart(grid.frameAt(hit.sourceTime));
    if (cut <= clip.inPoint) return this;
    return _commit(
      _replace(clip.id, [
        clip.copyWith(outPoint: cut),
        clip.copyWith(id: ClipId(_nextId), inPoint: cut),
      ]),
      nextId: _nextId + 1,
    );
  }

  /// Removes the clip; the clips after it close the gap.
  EditorSession remove(ClipId id) => _commit(_replace(id, const []));

  /// Moves the clip so it ends up at [index] in the sequence; an index off
  /// either end of the track is clamped to it.
  EditorSession move(ClipId id, int index) {
    final from = _indexOf(id);
    final to = index.clamp(0, editList.clips.length - 1);
    if (from == to) return this;
    final clips = [...editList.clips];
    clips.insert(to, clips.removeAt(from));
    return _commit(_withClips(clips));
  }

  /// Moves one edge of the clip to [sourceTime], snapped to the nearest frame
  /// boundary of its source. The edge stops at the source's start or end and
  /// one frame short of the other edge, the way a dragged edge stops in an
  /// editor; the clips after it follow.
  EditorSession trim(ClipId id, ClipEdge edge, Duration sourceTime) {
    final clip = editList.clips[_indexOf(id)];
    final source = editList.sourceOf(clip);
    final grid = source.frameRate;
    final snapped = grid.nearestFrameStart(
      _clamp(sourceTime, Duration.zero, source.duration),
    );
    final trimmed = switch (edge) {
      ClipEdge.inPoint => clip.copyWith(
        inPoint: _clamp(
          snapped,
          Duration.zero,
          grid.frameStart(grid.frameAt(clip.outPoint - _microsecond)),
        ),
      ),
      ClipEdge.outPoint => clip.copyWith(
        outPoint: _clamp(
          snapped,
          _min(
            grid.frameStart(grid.frameAt(clip.inPoint) + 1),
            source.duration,
          ),
          source.duration,
        ),
      ),
    };
    if (trimmed.inPoint == clip.inPoint && trimmed.outPoint == clip.outPoint) {
      return this;
    }
    return _commit(_replace(id, [trimmed]));
  }

  /// Removes every clip, as one undoable step.
  EditorSession clear() =>
      editList.clips.isEmpty ? this : _commit(const EditList());

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Goes back to the edit list before the last edit.
  EditorSession undo() => canUndo
      ? EditorSession._(_undo.last, _undo.sublist(0, _undo.length - 1), [
          ..._redo,
          editList,
        ], _nextId)
      : this;

  /// Reapplies the last undone edit.
  EditorSession redo() => canRedo
      ? EditorSession._(
          _redo.last,
          [..._undo, editList],
          _redo.sublist(0, _redo.length - 1),
          _nextId,
        )
      : this;

  int _indexOf(ClipId id) {
    final index = editList.clips.indexWhere((clip) => clip.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'no such clip');
    return index;
  }

  /// The edit list with the clip [id] replaced by [parts].
  EditList _replace(ClipId id, List<Clip> parts) {
    final index = _indexOf(id);
    return _withClips(
      [...editList.clips]..replaceRange(index, index + 1, parts),
    );
  }

  EditList _withClips(List<Clip> clips) =>
      EditList(clips: List.unmodifiable(clips), sources: editList.sources);

  /// Makes [next] current as one undo step and drops the redo history.
  EditorSession _commit(EditList next, {int? nextId}) =>
      EditorSession._(next, [..._undo, editList], const [], nextId ?? _nextId);
}

const _microsecond = Duration(microseconds: 1);

Duration _min(Duration a, Duration b) => a < b ? a : b;

Duration _clamp(Duration value, Duration lower, Duration upper) =>
    value < lower ? lower : (value > upper ? upper : value);
