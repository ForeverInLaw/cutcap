import 'dart:async';

import 'package:cutcap/player/preview_player.dart';
import 'package:flutter/widgets.dart';

/// A [PreviewPlayer] that records what it was asked to do. Tests drive
/// playback by calling [emitPosition] and [emitCompleted], and hold seeks
/// in flight with [holdSeeks].
final class FakePreviewPlayer implements PreviewPlayer {
  /// Calls in order: `open <path>`, `seek <µs>`, `play`, `pause`.
  final calls = <String>[];

  /// Paths [open] refuses with [UnplayableMedia].
  final unplayable = <String>{};

  /// While set, each seek waits until [releaseSeek] is called.
  bool holdSeeks = false;
  final _heldSeeks = <Completer<void>>[];

  final _position = StreamController<Duration>.broadcast(sync: true);
  final _completed = StreamController<void>.broadcast(sync: true);

  /// Seeks the player took, in microseconds.
  Iterable<int> get seeks => calls
      .where((call) => call.startsWith('seek '))
      .map((call) => int.parse(call.substring(5)));

  void emitPosition(Duration position) => _position.add(position);
  void emitCompleted() => _completed.add(null);

  /// Lets the oldest held seek complete.
  void releaseSeek() => _heldSeeks.removeAt(0).complete();

  @override
  Future<void> open(String path) async {
    calls.add('open $path');
    if (unplayable.contains(path)) throw UnplayableMedia(path);
  }

  @override
  Future<void> seek(Duration position) {
    calls.add('seek ${position.inMicroseconds}');
    if (!holdSeeks) return Future.value();
    final held = Completer<void>();
    _heldSeeks.add(held);
    return held.future;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {
    await _position.close();
    await _completed.close();
  }
}
