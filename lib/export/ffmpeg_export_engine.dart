import 'dart:async';
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
  /// [encoders] probes with [ffmpegPath] unless given (tests).
  FfmpegExportEngine({required String ffmpegPath, EncoderProbe? encoders})
    : _ffmpegPath = ffmpegPath,
      _encoders =
          encoders ??
          EncoderProbe(
            (arguments) async =>
                (await Process.run(ffmpegPath, arguments)).exitCode,
          );

  final String _ffmpegPath;
  final EncoderProbe _encoders;
  _Run? _running;

  @override
  Stream<ExportEvent> export(ExportJob job) {
    // A controller rather than async*: an async* body only notices a
    // cancelled subscription at its next yield, so a cancel during the
    // encoder probe or before ffmpeg's first progress line would wait.
    late final StreamController<ExportEvent> events;
    _Run? run;
    Future<void>? finished;
    events = StreamController(
      onListen: () {
        if (_running != null) {
          events.addError(StateError('An export is already running.'));
          unawaited(events.close());
          return;
        }
        final started = run = _running = _Run();
        finished = _export(job, started, events.add).whenComplete(() {
          _running = null;
          unawaited(events.close());
        });
      },
      // Waits until ffmpeg is gone and the partial file deleted.
      onCancel: () {
        run?.cancel();
        return finished;
      },
    );
    return events.stream;
  }

  /// Runs [job], reporting through [emit]; returns once ffmpeg has exited
  /// and a partial file is gone.
  Future<void> _export(
    ExportJob job,
    _Run run,
    void Function(ExportEvent event) emit,
  ) async {
    final partial = File('${job.outputPath}.part');
    var succeeded = false;
    try {
      final plan = ExportPlan.of(
        job.editList,
        missingSources: job.missingSources,
      );
      if (plan == null) return emit(nothingToExport);
      final encoder = await run.unlessCancelled(_encoders.encoder());
      if (run.cancelled) return emit(const ExportCancelled());
      if (encoder == null) {
        return emit(const ExportFailed(ExportFailure.noEncoder));
      }

      final process = await Process.start(
        _ffmpegPath,
        ffmpegExportArguments(plan, encoder, partial.path),
      );
      run.attach(process);
      final errors = _lastLines(process.stderr, 10);
      await for (final line in _lines(process.stdout)) {
        if (progressFraction(line, plan.duration) case final fraction?) {
          emit(ExportProgress(fraction));
        }
      }
      final exitCode = await process.exitCode;
      if (run.cancelled) return emit(const ExportCancelled());
      if (exitCode != 0) {
        final reason = await errors;
        return emit(
          ExportFailed(
            ExportFailure.failed,
            detail: reason.isEmpty
                ? 'ffmpeg exited with code $exitCode.'
                : reason,
          ),
        );
      }
      await partial.rename(job.outputPath);
      succeeded = true;
      emit(ExportSucceeded(job.outputPath));
    } on ProcessException catch (error) {
      emit(
        ExportFailed(
          ExportFailure.cannotStart,
          detail: '${error.executable}: ${error.message}',
        ),
      );
    } on FileSystemException catch (error) {
      emit(
        ExportFailed(
          ExportFailure.cannotWrite,
          detail: '${job.outputPath}: ${error.message}',
        ),
      );
    } finally {
      // Also reached when the listener cancels mid-export. Wait for ffmpeg
      // to exit so Windows releases the partial file before it is deleted.
      if (run.process case final process?) {
        process.kill();
        await process.exitCode;
      }
      if (!succeeded && partial.existsSync()) await partial.delete();
    }
  }

  @override
  void cancel() => _running?.cancel();
}

/// State of the export in progress.
final class _Run {
  bool cancelled = false;
  Process? process;
  final _cancel = Completer<void>();

  /// [step]'s value, or null as soon as the run is cancelled.
  Future<T?> unlessCancelled<T>(Future<T> step) =>
      Future.any([step, _cancel.future.then((_) => null)]);

  /// Tracks [started]; kills it at once when cancel came first.
  void attach(Process started) {
    process = started;
    if (cancelled) started.kill();
  }

  void cancel() {
    cancelled = true;
    process?.kill();
    if (!_cancel.isCompleted) _cancel.complete();
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
