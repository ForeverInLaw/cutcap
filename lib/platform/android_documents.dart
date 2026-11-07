import 'dart:async';

import 'android_channels.dart';

/// How the Android app gets at videos, over [AndroidChannels.documents]
/// (`VideoDocuments.kt`). Videos are `content://` URI strings; the Kotlin
/// side keeps read access to each across restarts where Android allows it
/// (see `docs/adr/0003-android-video-access.md`).
abstract final class AndroidDocuments {
  /// Opens the system picker for one or more videos; their URIs come back in
  /// the order the picker reports them, empty when the user cancels.
  static Future<List<String>> pick() async =>
      await AndroidChannels.documents.invokeListMethod<String>('pick') ??
      const [];

  /// Whether the video at [path] (URI or file path) can still be read.
  static Future<bool> exists(String path) async =>
      await AndroidChannels.documents.invokeMethod<bool>('exists', {
        'path': path,
      }) ??
      false;

  /// The video's size and modification time, as a thumbnail cache stamp
  /// (see `fileStamp`); null when it cannot be read.
  static Future<String?> stamp(String path) =>
      AndroidChannels.documents.invokeMethod<String>('stamp', {'path': path});

  /// The videos of the share that launched the app (and any that came
  /// before the editor listened to [shared]), in the order shared.
  static Future<List<String>> launchShares() async =>
      await AndroidChannels.documents.invokeListMethod<String>('takeShared') ??
      const [];

  /// Videos shared into the app while it runs ("Share → cutcap"), one batch
  /// per share in the order they were shared. Listen once, after
  /// [launchShares].
  static Stream<List<String>> shared() {
    late final StreamController<List<String>> batches;
    batches = StreamController(
      onListen: () async {
        AndroidChannels.documents.setMethodCallHandler((call) async {
          if (call.method != 'shared') return;
          final uris = (call.arguments as List<Object?>).whereType<String>();
          if (uris.isNotEmpty) batches.add(uris.toList());
        });
        // From now on the Kotlin side calls 'shared' itself; this collects
        // what arrived since [launchShares].
        final waiting =
            await AndroidChannels.documents.invokeListMethod<String>(
              'listenShared',
            ) ??
            const [];
        if (waiting.isNotEmpty) batches.add(waiting);
      },
      onCancel: () => AndroidChannels.documents.setMethodCallHandler(null),
    );
    return batches.stream;
  }
}
