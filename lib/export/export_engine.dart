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

  /// Where the mp4 goes. On Windows a file path: an existing file there is
  /// replaced, but only once the export has succeeded. On Android the file
  /// name in Movies/cutcap, where a name already taken gets a number
  /// instead (MediaStore picks it).
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
  const ExportSucceeded(this.outputPath, {this.displayName});

  /// The file path, or on Android the video's `content://` URI.
  final String outputPath;

  /// The name the system shows for the video when [outputPath] is no file
  /// path (Android).
  final String? displayName;
}

/// Nothing was written. [reason] is meant for the person exporting, e.g.
/// the last lines ffmpeg printed.
final class ExportFailed extends ExportOutcome {
  const ExportFailed(this.reason);

  final String reason;
}

/// What every engine reports when no clip is left to export.
const nothingToExport = ExportFailed(
  'There is nothing to export: the source files of all clips are missing.',
);

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
