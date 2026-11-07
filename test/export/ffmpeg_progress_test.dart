import 'package:cutcap/export/ffmpeg_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const total = Duration(seconds: 4);

  List<double> fractions(List<String> lines) => [
    for (final line in lines) ?progressFraction(line, total),
  ];

  test('reads written output time as a fraction of the total', () {
    // A block of `ffmpeg -progress pipe:1` output.
    expect(
      fractions([
        'frame=30',
        'fps=0.00',
        'out_time_us=1000000',
        'out_time_ms=1000000',
        'out_time=00:00:01.000000',
        'speed=2.01x',
        'progress=continue',
        'out_time_us=3000000',
      ]),
      [0.25, 0.75],
    );
  });

  test('ignores output time that is not known yet', () {
    expect(fractions(['out_time_us=N/A', 'out_time_us=-64000']), [0.0]);
  });

  test('reports the end as complete', () {
    expect(fractions(['out_time_us=4100000', 'progress=end']), [1.0, 1.0]);
  });
}
