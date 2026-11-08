/// How far an export is, from one line of `ffmpeg -progress` output: the
/// written output time as a fraction of [total] (0 to 1), 1 at the end, or
/// null for lines that say nothing about it.
double? progressFraction(String line, Duration total) {
  final separator = line.indexOf('=');
  if (separator < 0) return null;
  final value = line.substring(separator + 1).trim();
  return switch (line.substring(0, separator)) {
    'progress' when value == 'end' => 1,
    'out_time_us' => switch (int.tryParse(value)) {
      final us? => (us / total.inMicroseconds).clamp(0, 1).toDouble(),
      null => null,
    },
    _ => null,
  };
}
