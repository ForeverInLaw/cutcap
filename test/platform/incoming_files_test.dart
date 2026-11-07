import 'dart:io';

import 'package:cutcap/platform/incoming_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cutcap_incoming_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  String file(String name) {
    final path = p.join(dir.path, name);
    File(path).writeAsStringSync('');
    return path;
  }

  test('keeps existing files in the order they came', () {
    final b = file('b.mov');
    final a = file('a.mp4');

    expect(incomingFiles([b, a]), [b, a]);
  });

  test('drops folders, missing paths and switches', () {
    final clip = file('clip.mp4');
    final folder = Directory(p.join(dir.path, 'folder'))..createSync();

    expect(
      incomingFiles([
        '--verbose',
        folder.path,
        clip,
        p.join(dir.path, 'gone.mp4'),
      ]),
      [clip],
    );
  });

  test('resolves relative paths against the working directory', () {
    final clip = file('clip.mkv');
    final previous = Directory.current;
    Directory.current = dir;
    addTearDown(() => Directory.current = previous);

    expect(incomingFiles(['clip.mkv']), [p.normalize(clip)]);
  });
}
