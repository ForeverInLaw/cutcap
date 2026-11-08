import 'dart:convert';

import '../domain/editor_session.dart';

/// The saved form of an [EditList]: versioned JSON holding the sources (as
/// probed, so a restore needs no probing) and the clips in sequence order.
/// Undo history is not part of it. `displayName` was added within version 1
/// and may be absent.
///
/// ```json
/// {"version": 1,
///  "sources": [{"id": "C:/a.mp4", "path": "C:/a.mp4", "durationUs": 4000000,
///               "width": 1920, "height": 1080, "rotation": 0,
///               "frameRate": [30000, 1001], "averageFrameRate": null,
///               "videoBitRate": null, "hasAudio": true,
///               "displayName": null}],
///  "clips": [{"id": 0, "source": "C:/a.mp4", "inUs": 0, "outUs": 4000000}]}
/// ```
abstract final class SessionCodec {
  /// Format version written by [encode]. [decode] reads this version only.
  static const version = 1;

  static String encode(EditList list) => jsonEncode({
    'version': version,
    'sources': [for (final source in list.sources.values) _source(source)],
    'clips': [
      for (final clip in list.clips)
        {
          'id': clip.id.value,
          'source': clip.sourceId.value,
          'inUs': clip.inPoint.inMicroseconds,
          'outUs': clip.outPoint.inMicroseconds,
        },
    ],
  });

  /// The edit list saved in [json].
  ///
  /// Throws a [FormatException] when [json] is not a session of [version],
  /// or describes clips that could not exist.
  static EditList decode(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException('not JSON: ${error.message}');
    }
    if (root case {
      'version': final int saved,
      'sources': final List<Object?> sources,
      'clips': final List<Object?> clips,
    }) {
      if (saved != version) {
        throw FormatException('session format $saved, expected $version');
      }
      final byId = {
        for (final source in sources.map(_readSource)) source.id: source,
      };
      final read = [for (final clip in clips) _readClip(clip, byId)];
      if (read.map((clip) => clip.id).toSet().length != read.length) {
        throw const FormatException('clip ids repeat');
      }
      return EditList(
        clips: List.unmodifiable(read),
        sources: Map.unmodifiable(byId),
      );
    }
    throw const FormatException('not a cutcap session');
  }

  static Map<String, Object?> _source(Source source) => {
    'id': source.id.value,
    'path': source.path,
    'durationUs': source.duration.inMicroseconds,
    'width': source.resolution.width,
    'height': source.resolution.height,
    'rotation': source.rotation,
    'frameRate': _rate(source.frameRate),
    'averageFrameRate': switch (source.averageFrameRate) {
      final rate? => _rate(rate),
      null => null,
    },
    'videoBitRate': source.videoBitRate,
    'hasAudio': source.hasAudio,
    'displayName': source.displayName,
  };

  static List<int> _rate(FrameRate rate) => [rate.numerator, rate.denominator];

  static Source _readSource(Object? json) {
    if (json
        case {
          'id': final String id,
          'path': final String path,
          'durationUs': final int duration,
          'width': final int width,
          'height': final int height,
          'rotation': final int rotation,
          'frameRate': final Object frameRate,
          'averageFrameRate': final Object? averageFrameRate,
          'videoBitRate': final int? videoBitRate,
          'hasAudio': final bool hasAudio,
        }
        when duration > 0 &&
            width > 0 &&
            height > 0 &&
            const {0, 90, 180, 270}.contains(rotation)) {
      return Source(
        id: SourceId(id),
        path: path,
        duration: Duration(microseconds: duration),
        resolution: (width: width, height: height),
        rotation: rotation,
        frameRate: _readRate(frameRate),
        hasAudio: hasAudio,
        averageFrameRate: averageFrameRate == null
            ? null
            : _readRate(averageFrameRate),
        videoBitRate: videoBitRate,
        displayName: switch (json['displayName']) {
          final String name => name,
          _ => null,
        },
      );
    }
    throw FormatException('bad source: $json');
  }

  static FrameRate _readRate(Object json) => switch (json) {
    [final int numerator, final int denominator]
        when numerator > 0 && denominator > 0 =>
      FrameRate(numerator, denominator),
    _ => throw FormatException('bad frame rate: $json'),
  };

  static Clip _readClip(Object? json, Map<SourceId, Source> sources) {
    if (json case {
      'id': final int id,
      'source': final String sourceId,
      'inUs': final int inPoint,
      'outUs': final int outPoint,
    }) {
      final source = sources[SourceId(sourceId)];
      if (source != null &&
          inPoint >= 0 &&
          inPoint < outPoint &&
          outPoint <= source.duration.inMicroseconds) {
        return Clip(
          id: ClipId(id),
          sourceId: source.id,
          inPoint: Duration(microseconds: inPoint),
          outPoint: Duration(microseconds: outPoint),
        );
      }
    }
    throw FormatException('bad clip: $json');
  }
}
