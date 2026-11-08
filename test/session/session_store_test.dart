import 'dart:io';

import 'package:cutcap/domain/editor_session.dart';
import 'package:cutcap/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Source _source(String name, {int seconds = 4}) => Source(
  id: SourceId('C:/videos/$name'),
  path: 'C:/videos/$name',
  duration: Duration(seconds: seconds),
  resolution: (width: 1280, height: 720),
  rotation: 0,
  frameRate: const FrameRate(30, 1),
  hasAudio: true,
);

List<String> _paths(SavedSession saved) => [
  for (final clip in saved.editList!.clips) saved.editList!.sourceOf(clip).path,
];

void main() {
  late Directory dir;
  late File file;
  late SessionStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cutcap_session_');
    file = File(p.join(dir.path, 'nested', 'session.json'));
    store = SessionStore(() async => file);
  });

  tearDown(() => dir.delete(recursive: true));

  test('loads what it saved', () async {
    final list = const EditorSession().addSources([
      _source('a.mp4'),
      _source('b.mp4'),
    ]).editList;

    await store.save(list);

    expect(_paths(await SessionStore(() async => file).load()), [
      'C:/videos/a.mp4',
      'C:/videos/b.mp4',
    ]);
  });

  test('has nothing to load before the first save', () async {
    expect(await store.load(), isA<NoSavedSession>());
  });

  test('sets a corrupt file aside, where later saves leave it', () async {
    const corrupt = '{"version": 1, "sources": [';
    await file.parent.create(recursive: true);
    await file.writeAsString(corrupt);

    final saved = await store.load();
    expect(saved.editList, isNull);
    final keptAs = (saved as UnreadableSession).keptAs!;
    expect(p.basename(keptAs), startsWith('session.corrupt-'));
    expect(p.extension(keptAs), '.json');

    await store.save(
      const EditorSession().addSources([_source('a.mp4')]).editList,
    );
    expect(await File(keptAs).readAsString(), corrupt);
    expect(_paths(await store.load()), ['C:/videos/a.mp4']);
  });

  test('a save that cannot be written fails; the next one retries', () async {
    final blocked = SessionStore(() async => File(p.join(file.path, 'x')));
    final list = const EditorSession().addSources([_source('a.mp4')]).editList;
    // The session file's folder is a file.
    await file.parent.create(recursive: true);
    await file.writeAsString('');

    await expectLater(blocked.save(list), throwsA(isA<FileSystemException>()));

    await file.delete();
    await blocked.save(list);
    expect(_paths(await blocked.load()), ['C:/videos/a.mp4']);
  });

  test('writes the latest of saves that come faster than the disk', () async {
    var session = const EditorSession();
    final saves = <Future<void>>[];
    for (final name in ['a.mp4', 'b.mp4', 'c.mp4']) {
      session = session.addSources([_source(name)]);
      saves.add(store.save(session.editList));
    }
    await Future.wait(saves);

    expect(_paths(await store.load()), [
      'C:/videos/a.mp4',
      'C:/videos/b.mp4',
      'C:/videos/c.mp4',
    ]);
    expect(dir.listSync(recursive: true).whereType<File>(), hasLength(1));
  });
}
