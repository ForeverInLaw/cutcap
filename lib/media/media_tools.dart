import 'dart:io';

import 'package:path/path.dart' as p;

/// The command-line tools cutcap runs on desktop.
enum MediaTool {
  ffmpeg('ffmpeg'),
  ffprobe('ffprobe');

  const MediaTool(this.command);

  /// Executable name without extension.
  final String command;
}

/// Finds [MediaTool] executables: next to the app executable first (where
/// the installer bundles them), then on `PATH`.
///
/// ```dart
/// final ffmpeg = const MediaToolLocator().find(MediaTool.ffmpeg);
/// if (ffmpeg == null) { /* not installed */ }
/// ```
final class MediaToolLocator {
  const MediaToolLocator();

  /// Absolute path of [tool], or null when it is neither bundled nor on
  /// `PATH`.
  String? find(MediaTool tool) {
    final names = [
      for (final extension in _extensions) '${tool.command}$extension',
    ];
    final directories = [
      p.dirname(Platform.resolvedExecutable),
      ...?Platform.environment['PATH']?.split(_pathSeparator),
    ];
    for (final directory in directories) {
      if (directory.isEmpty) continue;
      for (final name in names) {
        final candidate = p.join(directory, name);
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return null;
  }

  static String get _pathSeparator => Platform.isWindows ? ';' : ':';

  static List<String> get _extensions => Platform.isWindows ? ['.exe'] : [''];
}
