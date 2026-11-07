import 'dart:convert';

import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/session/session_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const _ntsc = FrameRate(30000, 1001);

/// A rotated NTSC phone clip with variable rate, and a silent 25 fps clip.
final _phone = Source(
  id: const SourceId('C:/videos/phone.mp4'),
  path: 'C:/videos/phone.mp4',
  duration: const Duration(seconds: 12, microseconds: 345678),
  resolution: (width: 1920, height: 1080),
  rotation: 90,
  frameRate: _ntsc,
  hasAudio: true,
  averageFrameRate: const FrameRate(2997, 125),
  videoBitRate: 17000000,
);

final _screen = Source(
  id: const SourceId('D:/rec/screen.mkv'),
  path: 'D:/rec/screen.mkv',
  duration: const Duration(seconds: 8),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(25, 1),
  hasAudio: false,
);

/// Each clip as (source id, in, out) in microseconds.
List<(String, int, int)> _spans(EditList list) => [
  for (final clip in list.clips)
    (
      clip.sourceId.value,
      clip.inPoint.inMicroseconds,
      clip.outPoint.inMicroseconds,
    ),
];

EditorSession _roundTrip(EditorSession session) => EditorSession.restored(
  SessionCodec.decode(SessionCodec.encode(session.editList)),
);

void main() {
  final edited = const EditorSession()
      .addSources([_phone, _screen])
      .split(const Duration(seconds: 3))
      .trim(const ClipId(0), ClipEdge.inPoint, const Duration(seconds: 1));

  test('restores the clips and their sources as saved', () {
    final restored = _roundTrip(edited);

    expect(_spans(restored.editList), _spans(edited.editList));
    expect(restored.editList.clips.map((clip) => clip.id), [
      for (final clip in edited.editList.clips) clip.id,
    ]);
    final phone = restored.editList.sources[_phone.id]!;
    expect(phone.path, _phone.path);
    expect(phone.duration, _phone.duration);
    expect(phone.resolution, _phone.resolution);
    expect(phone.rotation, 90);
    expect(phone.frameRate, _ntsc);
    expect(phone.averageFrameRate, const FrameRate(2997, 125));
    expect(phone.videoBitRate, 17000000);
    expect(phone.hasAudio, isTrue);
    final screen = restored.editList.sources[_screen.id]!;
    expect(screen.hasAudio, isFalse);
    expect(screen.averageFrameRate, isNull);
    expect(screen.videoBitRate, isNull);
  });

  test('keeps snapping to the NTSC grid after a restore', () {
    // 0.5 s into the sequence is 1.501 s of the phone clip, inside NTSC frame
    // 44, which starts at 1.468133 s.
    final split = _roundTrip(edited).split(const Duration(milliseconds: 500));

    expect(_spans(split.editList).take(2), [
      ('C:/videos/phone.mp4', 1001000, 1468133),
      ('C:/videos/phone.mp4', 1468133, 2969633),
    ]);
  });

  test('starts without undo history and gives new clips fresh ids', () {
    final restored = _roundTrip(edited);

    expect(restored.canUndo, isFalse);
    expect(restored.canRedo, isFalse);
    final grown = restored.addSources([_screen]);
    final ids = grown.editList.clips.map((clip) => clip.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  group('rejects', () {
    final valid = SessionCodec.encode(edited.editList);

    test('text that is not a session', () {
      expect(() => SessionCodec.decode('{"clips": ['), throwsFormatException);
      expect(() => SessionCodec.decode('[]'), throwsFormatException);
    });

    test('a session from a newer version of the format', () {
      final newer = valid.replaceFirst(
        '"version":${SessionCodec.version}',
        '"version":${SessionCodec.version + 1}',
      );
      expect(newer, isNot(valid));
      expect(() => SessionCodec.decode(newer), throwsFormatException);
    });

    test('a clip whose source is not in the session', () {
      final json = jsonDecode(valid) as Map<String, Object?>;
      final sources = json['sources']! as List<Object?>;
      final orphaned = jsonEncode({
        ...json,
        'sources': sources.take(1).toList(),
      });
      expect(() => SessionCodec.decode(orphaned), throwsFormatException);
    });
  });
}
