import 'dart:io';

import 'package:path/path.dart' as p;

/// The files among [paths] handed to the app from outside (Explorer drops,
/// "Open with" arguments), as absolute paths in the order given.
///
/// Anything that is not an existing file is left out silently: folders,
/// vanished paths and command-line switches. Whether a file is a usable
/// video is the media probe's call, so the user hears about unreadable
/// files by name.
List<String> incomingFiles(Iterable<String> paths) => [
  for (final path in paths)
    if (FileSystemEntity.isFileSync(path)) p.normalize(p.absolute(path)),
];
