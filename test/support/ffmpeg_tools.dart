import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Whether this run is on CI (GitHub Actions sets `CI=true`), where the
/// `ffmpeg`-tagged tests must run: missing tools or a fixture this ffmpeg
/// cannot make fail them instead of skipping them.
final onCi = Platform.environment['CI'] == 'true';

/// The `skip:` value for an `ffmpeg`-tagged test: false when ffmpeg and
/// ffprobe both run, else the reason; never a reason on CI, so the tests
/// run there and fail.
Object ffmpegSkip() {
  final missing = ['ffmpeg', 'ffprobe'].where((tool) => !_runs(tool));
  if (missing.isEmpty || onCi) return false;
  return '${missing.join(' and ')} not on PATH';
}

/// Skips the running test because this ffmpeg lacks [what]; fails it on
/// CI instead.
void skipUnlessCi(String what) {
  if (onCi) fail('the ffmpeg on PATH $what');
  markTestSkipped('this ffmpeg $what');
}

bool _runs(String tool) {
  try {
    return Process.runSync(tool, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
