import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'thumbnail_source.dart';

/// Why a thumbnail could not be had.
final class ThumbnailUnavailable implements Exception {
  const ThumbnailUnavailable(this.videoPath, this.seek, this.reason);

  final String videoPath;
  final Duration seek;

  /// Diagnostic detail, not for display.
  final String reason;

  @override
  String toString() => 'ThumbnailUnavailable($videoPath @ $seek): $reason';
}

/// Filmstrip thumbnails on disk, rendered by a [ThumbnailSource] on demand.
///
/// Files live under [directory] in a folder per video, named from its
/// path and its [stamp] (by default [fileStamp]: size and modification
/// time), so a changed file gets new frames.
/// Requests made together are rendered together, one pass per video, the
/// newest first, and only one render runs at a time so the preview keeps
/// the machine. Decoded images are kept in memory by Flutter's image cache
/// (see `ThumbnailImage`); a frame that could not be rendered is not asked
/// for again while the app runs.
final class ThumbnailCache {
  ThumbnailCache({
    required this._source,
    required Future<Directory> Function() directory,
    this.batchSize = 16,
    this._stamp = fileStamp,
  }) : _locate = directory;

  final ThumbnailSource _source;
  final Future<String?> Function(String videoPath) _stamp;
  final Future<Directory> Function() _locate;
  late final Future<Directory> _directory = _locate();

  /// Most frames rendered in one pass.
  final int batchSize;

  final _folders = <String, Future<String?>>{};
  final _inFlight = <String, Future<Uint8List>>{};
  final _failed = <String>{};
  final _queue = <_Job>[];
  bool _pumpScheduled = false;
  bool _rendering = false;

  /// JPEG bytes of the frame of the video at [videoPath] shown after an
  /// exact seek to [seek], [height] px tall.
  ///
  /// Throws [ThumbnailUnavailable] when the video is gone or the frame
  /// cannot be rendered.
  Future<Uint8List> thumbnail(
    String videoPath,
    Duration seek, {
    required int height,
  }) async {
    final folder = await (_folders[videoPath] ??= _folderOf(videoPath));
    if (folder == null) {
      throw ThumbnailUnavailable(videoPath, seek, 'video not found');
    }
    final file = p.join(folder, '$height-${seek.inMicroseconds}.jpg');
    if (_failed.contains(file)) {
      throw ThumbnailUnavailable(videoPath, seek, 'could not be rendered');
    }
    return _inFlight[file] ??= _request(videoPath, seek, height, file);
  }

  Future<Uint8List> _request(
    String videoPath,
    Duration seek,
    int height,
    String file,
  ) async {
    final job = _Job(videoPath, height, (seek: seek, file: file));
    _queue.add(job);
    _schedulePump();
    try {
      return await job.done.future;
    } finally {
      unawaited(_inFlight.remove(file));
    }
  }

  /// The folder for the video's current contents, or null when it is gone.
  Future<String?> _folderOf(String videoPath) async {
    final stamp = await _stamp(videoPath);
    if (stamp == null) return null;
    final key = utf8.encode('$videoPath|$stamp');
    final name = sha1.convert(key).toString().substring(0, 20);
    return p.join((await _directory).path, name);
  }

  /// Runs the queue after the current event, so requests made together
  /// share a pass.
  void _schedulePump() {
    if (_pumpScheduled || _rendering) return;
    _pumpScheduled = true;
    Timer.run(() {
      _pumpScheduled = false;
      unawaited(_pump());
    });
  }

  Future<void> _pump() async {
    _rendering = true;
    try {
      while (_queue.isNotEmpty) {
        await _serve(_takeBatch());
      }
    } finally {
      _rendering = false;
    }
  }

  /// The newest job and the other queued jobs for the same video and
  /// height, newest first, up to [batchSize].
  List<_Job> _takeBatch() {
    final newest = _queue.last;
    final batch = _queue.reversed
        .where((job) => job.sameRender(newest))
        .take(batchSize)
        .toList();
    _queue.removeWhere(batch.contains);
    return batch;
  }

  /// Answers [batch] from disk and renders what is missing in one pass.
  Future<void> _serve(List<_Job> batch) async {
    final missing = <_Job>[];
    for (final job in batch) {
      final file = File(job.shot.file);
      if (await file.exists()) {
        job.done.complete(await file.readAsBytes());
      } else {
        missing.add(job);
      }
    }
    if (missing.isEmpty) return;
    final first = missing.first;
    try {
      await Directory(p.dirname(first.shot.file)).create(recursive: true);
      await _source.render(first.videoPath, [
        for (final job in missing) job.shot,
      ], height: first.height);
    } on Object catch (error) {
      for (final job in missing) {
        _fail(job, '$error');
      }
      return;
    }
    for (final job in missing) {
      final file = File(job.shot.file);
      if (await file.exists()) {
        job.done.complete(await file.readAsBytes());
      } else {
        _fail(job, 'not rendered');
      }
    }
  }

  void _fail(_Job job, String reason) {
    _failed.add(job.shot.file);
    job.done.completeError(
      ThumbnailUnavailable(job.videoPath, job.shot.seek, reason),
    );
  }
}

final class _Job {
  _Job(this.videoPath, this.height, this.shot);

  final String videoPath;
  final int height;
  final ThumbnailShot shot;
  final done = Completer<Uint8List>();

  bool sameRender(_Job other) =>
      other.videoPath == videoPath && other.height == height;
}

/// What tells the file at [path] apart from the same file changed: its size
/// and modification time; null when there is no such file.
Future<String?> fileStamp(String path) async {
  final stat = await File(path).stat();
  if (stat.type == FileSystemEntityType.notFound) return null;
  return '${stat.size}|${stat.modified.microsecondsSinceEpoch}';
}
