import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../theme/cutcap_tokens.dart';
import 'preview_player.dart';

/// [PreviewPlayer] on media_kit (libmpv). media_kit already runs mpv with
/// `hr-seek=yes`, so [seek] is frame-exact (ADR 0002); the video controller
/// sizes the surface from mpv's display size, which honours rotation.
///
/// Call `MediaKit.ensureInitialized()` once before creating one.
final class MediaKitPreviewPlayer implements PreviewPlayer {
  MediaKitPreviewPlayer() : _player = Player() {
    _controller = VideoController(_player);
  }

  final Player _player;
  late final VideoController _controller;

  /// How long a file may take to load before it counts as unplayable.
  static const _loadTimeout = Duration(seconds: 10);

  @override
  Future<void> open(String path) async {
    // Subscribe before opening: the length arrives once mpv has loaded the
    // file, which is also when it accepts seeks.
    final loaded = _player.stream.duration
        .firstWhere((duration) => duration > Duration.zero)
        .timeout(_loadTimeout);
    await _player.open(Media(path), play: false);
    await loaded;
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<void> get completed =>
      _player.stream.completed.where((completed) => completed);

  @override
  Widget buildView() => Video(
    controller: _controller,
    controls: null,
    fill: CutcapTokens.preview,
    wakelock: false,
  );

  @override
  Future<void> dispose() => _player.dispose();
}
