import '../media/media_tools.dart';
import 'encoder_probe.dart';
import 'export_plan.dart';

/// The ffmpeg command line (without the executable) that renders [plan]
/// with [encoder] into an mp4 at [outputPath], following the template in
/// ADR 0002: one input per clip, sought to its first frame, and one filter
/// graph that trims each clip to whole output frames, fits it into the
/// output size with black bars, conforms rate and colour, fills missing
/// audio with silence and concatenates. Progress goes to stdout.
List<String> ffmpegExportArguments(
  ExportPlan plan,
  H264Encoder encoder,
  String outputPath,
) => [
  '-hide_banner',
  '-nostdin',
  '-y',
  '-loglevel',
  'error',
  '-nostats',
  '-progress',
  'pipe:1',
  for (final clip in plan.clips) ...[
    '-ss',
    ffmpegSeconds(clip.seek),
    '-i',
    clip.path,
  ],
  '-filter_complex',
  _filterGraph(plan),
  '-map',
  '[v]',
  '-map',
  '[a]',
  ...encoder.arguments(plan.videoBitRate),
  '-c:a',
  'aac',
  '-b:a',
  '192k',
  '-movflags',
  '+faststart',
  '-f',
  'mp4',
  outputPath,
];

String _filterGraph(ExportPlan plan) {
  final (:width, :height) = plan.size;
  final video = [
    'scale=$width:$height:force_original_aspect_ratio=decrease'
        ':out_color_matrix=bt709:out_range=tv',
    'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black',
    'setsar=1',
    'fps=${plan.frameRate}',
    'format=nv12',
    'setparams=range=tv:colorspace=bt709:color_primaries=bt709'
        ':color_trc=bt709',
  ].join(',');
  const audio =
      'aformat=sample_fmts=fltp:sample_rates=$exportSampleRate'
      ':channel_layouts=stereo';

  final chains = <String>[];
  for (final (i, clip) in plan.clips.indexed) {
    final duration = ffmpegSeconds(clip.duration);
    final samples = clip.audioSamples;
    chains.add(
      '[$i:v:0]trim=duration=$duration,setpts=PTS-STARTPTS,$video,'
      'tpad=stop_mode=clone:stop=-1,trim=end_frame=${clip.frames}[v$i]',
    );
    chains.add(
      clip.hasAudio
          ? '[$i:a:0]atrim=duration=$duration,asetpts=PTS-STARTPTS,$audio,'
                'apad=whole_len=$samples,atrim=end_sample=$samples[a$i]'
          : 'anullsrc=r=$exportSampleRate:cl=stereo,$audio,'
                'atrim=end_sample=$samples[a$i]',
    );
  }
  final pads = [for (var i = 0; i < plan.clips.length; i++) '[v$i][a$i]'];
  chains.add('${pads.join()}concat=n=${plan.clips.length}:v=1:a=1[v][a]');
  return chains.join(';');
}
