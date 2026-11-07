import 'package:cutcap/export/encoder_probe.dart';
import 'package:flutter_test/flutter_test.dart';

/// An ffmpeg stand-in where only the [working] encoders exit 0. Records the
/// encoder of every run.
final class FakeFfmpeg {
  FakeFfmpeg(this.working);

  final Set<String> working;
  final tried = <String>[];
  final calls = <List<String>>[];

  Future<int> call(List<String> arguments) async {
    calls.add(arguments);
    final encoder = arguments[arguments.indexOf('-c:v') + 1];
    tried.add(encoder);
    return working.contains(encoder) ? 0 : 1;
  }
}

void main() {
  test('tries nvenc, amf, qsv, mf, libx264 in turn and takes the first '
      'that encodes', () async {
    final ffmpeg = FakeFfmpeg({'h264_mf', 'libx264'});

    final encoder = await EncoderProbe(ffmpeg.call).encoder();

    expect(encoder, H264Encoder.mediaFoundation);
    expect(ffmpeg.tried, ['h264_nvenc', 'h264_amf', 'h264_qsv', 'h264_mf']);
  });

  test('falls through to libx264 on a machine without GPU encoders', () async {
    final ffmpeg = FakeFfmpeg({'libx264'});

    expect(await EncoderProbe(ffmpeg.call).encoder(), H264Encoder.x264);
  });

  test('finds no encoder when none works', () async {
    expect(await EncoderProbe(FakeFfmpeg({}).call).encoder(), isNull);
  });

  test('probes once and remembers the result', () async {
    final ffmpeg = FakeFfmpeg({'h264_amf'});
    final probe = EncoderProbe(ffmpeg.call);

    final results = await Future.wait([probe.encoder(), probe.encoder()]);
    await probe.encoder();

    expect(results, [H264Encoder.amf, H264Encoder.amf]);
    expect(ffmpeg.tried, ['h264_nvenc', 'h264_amf']);
  });

  test('encodes real nv12 frames with the options the export uses', () async {
    // h264_mf only fails on yuv420p and `-profile:v high` (ADR 0002), so a
    // probe with other settings would pass where the export then fails.
    final ffmpeg = FakeFfmpeg({});
    await EncoderProbe(ffmpeg.call).encoder();

    final mf = ffmpeg.calls.firstWhere((args) => args.contains('h264_mf'));
    expect(mf.join(' '), contains('-hw_encoding 1'));
    expect(mf.join(' '), contains('-profile:v 100'));
    expect(mf.join(' '), contains('nv12'));
    expect(mf.join(' '), contains('-frames:v 5'));
  });
}
