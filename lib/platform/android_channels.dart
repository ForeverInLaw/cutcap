import 'package:flutter/services.dart';

/// Channels to the Kotlin side of the Android app (`android/app/src/main/
/// kotlin/.../MainActivity.kt`). Names must match there.
abstract final class AndroidChannels {
  /// Probing and thumbnails (`MediaChannel.kt`).
  static const media = MethodChannel('io.github.foreverinlaw.cutcap/media');

  /// Picking, keeping and checking videos, and videos shared into the app
  /// (`VideoDocuments.kt`).
  static const documents = MethodChannel(
    'io.github.foreverinlaw.cutcap/documents',
  );

  /// Cancelling the running export, and opening or sharing a finished one
  /// (`ExportChannel.kt`).
  static const export = MethodChannel('io.github.foreverinlaw.cutcap/export');

  /// One export per listen: the request goes with the listen, its events
  /// come back (`ExportChannel.kt`).
  static const exportRun = EventChannel(
    'io.github.foreverinlaw.cutcap/export/run',
  );
}
