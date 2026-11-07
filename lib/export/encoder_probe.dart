/// The H.264 encoders an export can use, in probe order (fastest hardware
/// first), each with the options the export passes to it (ADR 0002).
enum H264Encoder {
  nvenc('h264_nvenc', ['-preset', 'p5', '-rc', 'vbr', '-profile:v', 'high']),
  amf('h264_amf', [
    '-quality',
    'balanced',
    '-rc',
    'vbr_peak',
    '-profile:v',
    'high',
  ]),
  qsv('h264_qsv', ['-preset', 'medium', '-profile:v', 'high']),
  // Without -hw_encoding the software MFT answers and the probe lies; the
  // hardware MFT wants nv12 and a numeric profile (100 = High).
  mediaFoundation('h264_mf', [
    '-hw_encoding',
    '1',
    '-rate_control',
    'pc_vbr',
    '-profile:v',
    '100',
  ]),
  x264('libx264', ['-preset', 'veryfast', '-profile:v', 'high']);

  const H264Encoder(this.ffmpegName, this.options);

  /// The `-c:v` value.
  final String ffmpegName;

  /// Encoder options that follow `-c:v`.
  final List<String> options;

  /// `-c:v` with this encoder and its options, then the rate control for
  /// [bitRate] bits per second (ADR 0002: max 1.5×, buffer 2×).
  List<String> arguments(int bitRate) => [
    '-c:v',
    ffmpegName,
    ...options,
    '-b:v',
    '${bitRate ~/ 1000}k',
    '-maxrate',
    '${bitRate * 3 ~/ 2000}k',
    '-bufsize',
    '${bitRate * 2 ~/ 1000}k',
  ];
}

/// Runs ffmpeg with [arguments] to completion and returns its exit code.
typedef FfmpegRun = Future<int> Function(List<String> arguments);

/// Finds the first [H264Encoder] that works on this machine by encoding a
/// few real frames with each, since `ffmpeg -encoders` lists encoders whose
/// hardware is absent. Probes once; later calls get the same answer.
final class EncoderProbe {
  EncoderProbe(this._run);

  final FfmpegRun _run;
  Future<H264Encoder?>? _result;

  /// The encoder to export with, or null when none works. A run that throws
  /// (ffmpeg missing, say) is not remembered.
  Future<H264Encoder?> encoder() =>
      _result ??= _probe().onError<Object>((error, stackTrace) {
        _result = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  Future<H264Encoder?> _probe() async {
    for (final encoder in H264Encoder.values) {
      if (await _run(_probeArguments(encoder)) == 0) return encoder;
    }
    return null;
  }
}

/// Five 256×256 nv12 frames through [encoder] into the null muxer.
List<String> _probeArguments(H264Encoder encoder) => [
  '-hide_banner',
  '-nostdin',
  '-loglevel',
  'error',
  '-f',
  'lavfi',
  '-i',
  'color=c=black:s=256x256:r=30',
  '-frames:v',
  '5',
  '-vf',
  'format=nv12',
  ...encoder.arguments(2000000),
  '-f',
  'null',
  '-',
];
