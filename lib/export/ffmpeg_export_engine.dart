import 'dart:convert';
import 'dart:io';

import 'encoder_probe.dart';
import 'export_engine.dart';
import 'export_plan.dart';
import 'ffmpeg_command.dart';
import 'ffmpeg_progress.dart';

/// The Windows [ExportEngine]: runs the ffmpeg at [ffmpegPath] as a child
/// process with the ADR 0002 command. The encoder is probed on the first
/// export and reused for the engine's lifetime. ffmpeg writes to
/// `<output>.part`, which becomes the output only when it succeeds.
final class FfmpegExportEngine implements ExportEngine {
  FfmpegExportEngine({required String ffmpegPath})
    : _ffmpegPath = ffmpegPath,
      _encoders = EncoderProbe(
        (arguments) async =>
            (await Process.run(ffmpegPath, arguments)).exitCode,
      );

  final String _ffmpegPath;
  final EncoderProbe _encoders;
  _Run? _running;

  @override
  Stream<ExportEvent> export(ExportJob job) async* {
    if (_running != null) throw StateError('An export is already running.');
    final run = _running = _Run();
    final partial = File('${job.outputPath}.part');
    var succeeded = false;
    try {
      final plan = ExportPlan.of(
        job.editList,
        missingSources: job.missingSources,
      );
      if (plan == null) {
        yield nothingToExport;
        return;
      }
      final encoder = await _encoders.encoder();
      if (run.cancelled) {
        yield const ExportCancelled();
        return;
      }
      if (encoder == null) {
        yield ExportFailed('No H.264 encoder works with $_ffmpegPath.');
        return;
      }

      final process = await Process.start(
        _ffmpegPath,
        ffmpegExportArguments(plan, encoder, partial.path),
      );
      run.attach(process);
      final errors = _lastLines(process.stderr, 10);
      await for (final line in _lines(process.stdout)) {
        if (progressFraction(line, plan.duration) case final fraction?) {
          yield ExportProgress(fraction);
        }
      }
      final exitCode = await process.exitCode;
      if (run.cancelled) {
        yield const ExportCancelled();
        return;
      }
      if (exitCode != 0) {
        final reason = await errors;
        yield ExportFailed(
          reason.isEmpty ? 'ffmpeg exited with code $exitCode.' : reason,
        );
        return;
      }
      await partial.rename(job.outputPath);
      succeeded = true;
      yield ExportSucceeded(job.outputPath);
    } on ProcessException catch (error) {
      yield ExportFailed('Could not run ${error.executable}: ${error.message}');
    } on FileSystemException catch (error) {
      yield ExportFailed('Could not write ${job.outputPath}: ${error.message}');
    } finally {
      // Also reached when the listener cancels mid-export. Wait for ffmpeg
      // to exit so Windows releases the partial file before it is deleted.
      if (run.process case final process?) {
        process.kill();
        await process.exitCode;
      }
      if (!succeeded && partial.existsSync()) await partial.delete();
      _running = null;
    }
  }

  @override
  void cancel() => _running?.cancel();
}

/// State of the export in progress.
final class _Run {
  bool cancelled = false;
  Process? process;

  /// Tracks [started]; kills it at once when cancel came first.
  void attach(Process started) {
    process = started;
    if (cancelled) started.kill();
  }

  void cancel() {
    cancelled = true;
    process?.kill();
  }
}

Stream<String> _lines(Stream<List<int>> bytes) => bytes
    .transform(const Utf8Decoder(allowMalformed: true))
    .transform(const LineSplitter());

/// The last [count] non-empty lines of [bytes], joined, once it closes.
Future<String> _lastLines(Stream<List<int>> bytes, int count) async {
  final tail = <String>[];
  await for (final line in _lines(bytes)) {
    if (line.trim().isEmpty) continue;
    tail.add(line);
    if (tail.length > count) tail.removeAt(0);
  }
  return tail.join('\n');
}
