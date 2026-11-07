import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

  /// The saved edit list, or null when there is none or it cannot be read.
  /// An unreadable file is reported in the log and otherwise ignored.
  Future<EditList?> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return null;
      return SessionCodec.decode(await file.readAsString());
    } on Object catch (error) {
      // Corrupt, unreadable or nowhere to keep it: start empty, never crash.
      debugPrint('cutcap: ignoring the saved session: $error');
      return null;
    }
  }

  /// Saves [list]; completes once it, or a later save, is written. A failed
  /// write is reported in the log; the next save tries again.
  Future<void> save(EditList list) {
    _pending = list;
    return _writing ??= _drain();
  }

  /// Completes once every save made so far is written.
  Future<void> flush() => _writing ?? Future.value();

  Future<void> _drain() async {
    try {
      for (var list = _pending; list != null; list = _pending) {
        _pending = null;
        await _write(list);
      }
    } finally {
      _writing = null;
    }
  }

  Future<void> _write(EditList list) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(SessionCodec.encode(list), flush: true);
      await temporary.rename(file.path);
    } on Object catch (error) {
      // Autosave must never take the editor down; the next edit retries.
      debugPrint('cutcap: could not save the session: $error');
    }
  }
}
