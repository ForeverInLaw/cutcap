import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/edit_list.dart';
import 'session_codec.dart';

/// Keeps the current [EditList] in one JSON file ([SessionCodec]) so the
/// edit survives the app closing.
///
/// Saves never queue up: while one is being written, newer ones replace
/// each other and only the latest is written next. Each write goes to a
/// temporary file that then replaces the session file, so a crash mid-write
/// leaves the previous session intact.
final class SessionStore {
  /// [locate] names the session file; it is called once, on first use.
  SessionStore(Future<File> Function() locate) : _locate = locate;

  final Future<File> Function() _locate;
  late final Future<File> _file = _locate();

  EditList? _pending;
  Future<void>? _writing;

  /// The saved edit. A file that cannot be read is moved aside first, to
  /// `session.corrupt-<timestamp>.json` next to it, so no later save
  /// overwrites what may still be the user's work.
  Future<SavedSession> load() async {
    final File file;
    try {
      file = await _file;
      if (!await file.exists()) return const NoSavedSession();
      return RestoredSession(SessionCodec.decode(await file.readAsString()));
    } on Object catch (error) {
      // Corrupt, unreadable or nowhere to keep it: start empty, never crash.
      debugPrint('cutcap: cannot read the saved session: $error');
      return UnreadableSession(await _setAside());
    }
  }

  /// Saves [list]; completes once it, or a later save, is written, and
  /// fails with that write's error. The next save tries again.
  Future<void> save(EditList list) {
    _pending = list;
    return _writing ??= _drain();
  }

  /// Completes once every save made so far is written.
  Future<void> flush() => _writing ?? Future.value();

  Future<void> _drain() async {
    try {
      Object? failure;
      StackTrace? failureStack;
      for (var list = _pending; list != null; list = _pending) {
        _pending = null;
        try {
          await _write(list);
          failure = null;
        } on Object catch (error, stack) {
          // A newer save may still get through; only the last one counts.
          (failure, failureStack) = (error, stack);
        }
      }
      if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
    } finally {
      _writing = null;
    }
  }

  Future<void> _write(EditList list) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(SessionCodec.encode(list), flush: true);
    await temporary.rename(file.path);
  }

  /// Moves the session file aside and returns where to, or null when it
  /// could not be moved (or there is no file to move).
  Future<String?> _setAside() async {
    try {
      final file = await _file;
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp('[^0-9]'),
        '',
      );
      final name =
          '${p.basenameWithoutExtension(file.path)}.corrupt-$stamp'
          '${p.extension(file.path)}';
      return (await file.rename(p.join(file.parent.path, name))).path;
    } on Object catch (error) {
      debugPrint('cutcap: could not set the saved session aside: $error');
      return null;
    }
  }
}

/// What [SessionStore.load] found.
sealed class SavedSession {
  const SavedSession();

  /// The edit to continue, if one was read.
  EditList? get editList => null;
}

/// Nothing was saved yet.
final class NoSavedSession extends SavedSession {
  const NoSavedSession();
}

final class RestoredSession extends SavedSession {
  const RestoredSession(this.editList);

  @override
  final EditList editList;
}

/// The session file could not be read; it was moved to [keptAs], or left
/// where it was when that failed (null).
final class UnreadableSession extends SavedSession {
  const UnreadableSession(this.keptAs);

  final String? keptAs;
}
