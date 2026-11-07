import '../domain/edit_list.dart';
import '../domain/source.dart';

/// One export: the sequence and the file it goes to.
final class ExportJob {
  const ExportJob({
    required this.editList,
    required this.outputPath,
    this.missingSources = const {},
  });

  final EditList editList;

  /// Where the mp4 goes. An existing file there is replaced, but only once
  /// the export has succeeded.
  final String outputPath;

  /// Sources whose file is gone. Their clips are left out of the export.
  final Set<SourceId> missingSources;
}

/// What an export reports while it runs.
sealed class ExportEvent {
  const ExportEvent();
}

/// How much of the output is written, from 0 to 1.
final class ExportProgress extends ExportEvent {
  const ExportProgress(this.fraction);

  final double fraction;
}

/// How an export ended; the last event of every export.
sealed class ExportOutcome extends ExportEvent {
  const ExportOutcome();
}

/// The file at [outputPath] is complete.
final class ExportSucceeded extends ExportOutcome {
  const ExportSucceeded(this.outputPath);

  final String outputPath;
}

/// Nothing was written. [reason] is meant for the person exporting, e.g.
/// the last lines ffmpeg printed.
final class ExportFailed extends ExportOutcome {
  const ExportFailed(this.reason);

  final String reason;
}

/// Stopped by [ExportEngine.cancel]; nothing was written.
final class ExportCancelled extends ExportOutcome {
  const ExportCancelled();
}

/// Renders an [EditList] to an H.264/AAC mp4 by the spec's output rules.
/// One implementation per platform.
abstract interface class ExportEngine {
  /// Starts exporting [job] once listened to. The stream reports
  /// [ExportProgress] and ends with exactly one [ExportOutcome], then closes.
  /// Runs one export at a time: a second export while one runs fails with a
  /// [StateError]. Cancelling the subscription stops the export like
  /// [cancel] does.
  Stream<ExportEvent> export(ExportJob job);

  /// Stops the running export, which then ends with [ExportCancelled] and
  /// leaves no file behind. Does nothing when no export runs.
  void cancel();
}
