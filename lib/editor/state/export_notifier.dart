import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../export/export_engine.dart' as engine;
import '../../export/ffmpeg_export_engine.dart';
import '../../media/media_tools.dart';
import '../../platform/open_file.dart';
import '../editor_view_state.dart';
import 'editor_state.dart';

/// The export engine for this app session, or null when ffmpeg is neither
/// bundled nor on `PATH`. Kept for the session so the encoder is probed
/// once.
final exportEngineProvider = Provider<engine.ExportEngine?>((ref) {
  final ffmpeg = const MediaToolLocator().find(MediaTool.ffmpeg);
  return ffmpeg == null ? null : FfmpegExportEngine(ffmpegPath: ffmpeg);
});

/// Asks the user where to save the export, offering [suggestedName];
/// null when they back out.
final saveLocationProvider =
    Provider<Future<String?> Function(String suggestedName)>(
      (ref) => _askSaveLocation,
    );

/// Opens a finished export with the system's default app.
final fileOpenerProvider = Provider<void Function(String path)>(
  (ref) => openWithDefaultApp,
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
  /// The file the last export went (or was meant) to.
  String? _target;
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
      '${p.basenameWithoutExtension(first.path)}-cut.mp4',
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
    final target = _target;
    if (target != null && state is ExportDone) {
      ref.read(fileOpenerProvider)(target);
    }
  }

  /// Hides the outcome of the last export.
  void dismiss() {
    if (state is! ExportRunning) state = const ExportIdle();
  }

  void _export(String target) {
    _target = target;
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
            engine.ExportSucceeded(:final outputPath) => ExportDone(
              fileName: p.basename(outputPath),
            ),
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
}
