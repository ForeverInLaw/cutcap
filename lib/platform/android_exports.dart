import 'android_channels.dart';

/// What the Android app does with a finished export, over
/// [AndroidChannels.export] (`ExportChannel.kt`). [uri] is the video's
/// MediaStore URI, as `AndroidExportEngine` reports it.
abstract final class AndroidExports {
  /// Shows the video in the app the user plays videos with.
  static Future<void> open(String uri) =>
      AndroidChannels.export.invokeMethod<void>('open', {'uri': uri});

  /// Offers the video to other apps through the system share sheet.
  static Future<void> share(String uri) =>
      AndroidChannels.export.invokeMethod<void>('share', {'uri': uri});
}
