import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../export/android_export_engine.dart';
import '../../export/export_engine.dart' as engine;
import '../../export/ffmpeg_export_engine.dart';
import '../../media/media_tools.dart';
import '../../platform/android_exports.dart';
import '../../platform/open_file.dart';
import '../editor_view_state.dart';
import 'editor_state.dart';

/// The export engine for this app session: Media3 on Android; on desktop
/// ffmpeg, or null when it is neither bundled nor on `PATH`. Kept for the
/// session so the encoder is probed once.
final exportEngineProvider = Provider<engine.ExportEngine?>((ref) {
  if (Platform.isAndroid) return AndroidExportEngine();
  final ffmpeg = const MediaToolLocator().find(MediaTool.ffmpeg);
  return ffmpeg == null ? null : FfmpegExportEngine(ffmpegPath: ffmpeg);
});

/// Where the export goes, given [suggestedName]; null when the user backs
/// out. Desktop asks with a Save as dialog; Android always saves under the
/// suggested name in Movies/cutcap.
final saveLocationProvider =
    Provider<Future<String?> Function(String suggestedName)>(
      (ref) => Platform.isAndroid ? Future.value : _askSaveLocation,
    );

/// Opens a finished export (a path, on Android its URI) with the system's
/// default app.
final fileOpenerProvider = Provider<void Function(String path)>(
  (ref) => Platform.isAndroid
      ? (uri) => unawaited(AndroidExports.open(uri))
      : openWithDefaultApp,
);

/// Hands a finished export to the system share sheet; null where there is
/// none (desktop), which also hides Share.
final fileSharerProvider = Provider<void Function(String path)?>(
  (ref) =>
      Platform.isAndroid ? (uri) => unawaited(AndroidExports.share(uri)) : null,
);

Future<String?> _askSaveLocation(String suggestedName) async {
  const mp4 = XTypeGroup(
    label: 'MP4',
    extensions: ['mp4'],
    mimeTypes: ['video/mp4'],
    uniformTypeIdentifiers: ['public.mpeg-4'],
  );
  final location = await getSaveLocation(
    acceptedTypeGroups: const [mp4],
    suggestedName: suggestedName,
  );
  return location?.path;
}

final exportProvider = NotifierProvider<ExportNotifier, ExportStatus>(
  ExportNotifier.new,
);

/// Runs exports of the edit and reports where they stand as the status
/// band's [ExportStatus].
final class ExportNotifier extends Notifier<ExportStatus> {
  /// The file the last export was meant to go to.
  String? _target;

  /// Where the last successful export is: [_target], or on Android the
  /// saved video's URI.
  String? _output;
  StreamSubscription<engine.ExportEvent>? _run;

  @override
  ExportStatus build() {
    ref.onDispose(() => unawaited(_run?.cancel()));
    return const ExportIdle();
  }

  /// Asks where to save, then exports the edit there.
  Future<void> start() async {
    final list = ref.read(sessionProvider).editList;
    if (list.clips.isEmpty || state is ExportRunning) return;
    final first = list.sourceOf(list.clips.first);
    final chosen = await ref.read(saveLocationProvider)(
      '${p.basenameWithoutExtension(first.name)}-cut.mp4',
    );
    if (chosen == null) return;
    // The Windows dialog returns a typed name as is.
    _export(p.extension(chosen).isEmpty ? '$chosen.mp4' : chosen);
  }

  /// Exports again to the file the failed export was meant for, or asks
  /// for another file when that one was refused.
  Future<void> retry() async {
    final target = _target;
    switch (state) {
      case ExportFailed(problem: ExportProblem.targetIsSource):
        await start();
      case ExportFailed() when target != null:
        _export(target);
      default:
    }
  }

  /// Stops the running export; the band returns to rest once it has.
  void cancel() {
    if (state is ExportRunning) ref.read(exportEngineProvider)?.cancel();
  }

  /// Opens the finished export with the default app.
  void open() {
    final output = _output;
    if (output != null && state is ExportDone) {
      ref.read(fileOpenerProvider)(output);
    }
  }

  /// Offers the finished export to other apps (Android).
  void share() {
    final output = _output;
    final sharer = ref.read(fileSharerProvider);
    if (output != null && sharer != null && state is ExportDone) {
      sharer(output);
    }
  }

  /// Hides the outcome of the last export.
  void dismiss() {
    if (state is! ExportRunning) state = const ExportIdle();
  }

  void _export(String target) {
    _target = target;
    _output = null;
    final list = ref.read(sessionProvider).editList;
    final exporter = ref.read(exportEngineProvider);
    if (exporter == null) {
      state = const ExportFailed(ExportProblem.exporterMissing);
      return;
    }
    // ffmpeg would read the file while writing over it.
    if (list.sources.values.any((source) => p.equals(source.path, target))) {
      state = const ExportFailed(ExportProblem.targetIsSource);
      return;
    }
    state = const ExportRunning(0);
    final job = engine.ExportJob(
      editList: list,
      outputPath: target,
      missingSources: ref.read(missingSourcesProvider),
    );
    _run = exporter
        .export(job)
        .listen(
          (event) => state = switch (event) {
            engine.ExportProgress(:final fraction) => ExportRunning(fraction),
            engine.ExportSucceeded(:final outputPath, :final displayName) =>
              _done(outputPath, displayName),
            engine.ExportFailed(:final reason) => ExportFailed(
              ExportProblem.failed,
              detail: reason,
            ),
            engine.ExportCancelled() => const ExportIdle(),
          },
          // The engine refused to start, e.g. another export is running.
          onError: (Object error) =>
              state = ExportFailed(ExportProblem.failed, detail: '$error'),
          onDone: () => _run = null,
        );
  }

  ExportDone _done(String output, String? displayName) {
    _output = output;
    return ExportDone(
      fileName: displayName ?? p.basename(output),
      canShare: ref.read(fileSharerProvider) != null,
    );
  }
}
