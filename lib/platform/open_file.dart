import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Opens the file at [path] the way double-clicking it in Explorer would,
/// with the app the user chose for its type (Windows only).
///
/// Goes through `ShellExecuteW` rather than a child process: a command
/// line through `explorer.exe` or `cmd /c start` misreads paths holding
/// commas, `&` or `%`.
void openWithDefaultApp(String path) => using((arena) {
  final result = ShellExecute(
    null,
    null,
    arena.pcwstr(path),
    null,
    null,
    SW_SHOWNORMAL,
  );
  // Values up to 32 are error codes (shellapi.h).
  if (result.address <= 32) {
    throw OpenFileException(path, result.address);
  }
});

/// The shell could not open [path]; [code] is ShellExecute's error value.
final class OpenFileException implements Exception {
  const OpenFileException(this.path, this.code);

  final String path;
  final int code;

  @override
  String toString() => 'Could not open $path (ShellExecute error $code).';
}
