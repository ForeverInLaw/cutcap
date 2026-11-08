import 'dart:async';

import 'package:flutter/services.dart';

import '../platform/android_channels.dart';
import 'export_engine.dart';
import 'export_plan.dart';

/// The Android [ExportEngine]: Media3 Transformer in a foreground service
/// (`ExportService.kt`), reached over [AndroidChannels.exportRun]. The plan
/// is worked out here, so both platforms follow the same output rules; the
/// Kotlin side turns it into a Media3 composition and saves the result to
/// Movies/cutcap under the job's [ExportJob.outputPath] name.
///
/// The service carries on when the app goes to the background. When the
/// app's engine goes away mid-export, the export still finishes and its
/// notification tells how it ended.
final class AndroidExportEngine implements ExportEngine {
  bool _running = false;

  @override
  Stream<ExportEvent> export(ExportJob job) {
    // A controller rather than async*: an async* body only notices a
    // cancelled subscription at its next yield, so a run that has not
    // reported yet would keep going.
    late final StreamController<ExportEvent> events;
    StreamSubscription<Object?>? run;
    void end([ExportEvent? last]) {
      if (last != null) events.add(last);
      unawaited(run?.cancel());
      _running = false;
      unawaited(events.close());
    }

    events = StreamController(
      onListen: () {
        if (_running) {
          events.addError(StateError('An export is already running.'));
          unawaited(events.close());
          return;
        }
        final plan = ExportPlan.of(
          job.editList,
          missingSources: job.missingSources,
        );
        if (plan == null) return end(nothingToExport);
        _running = true;
        // Listening starts the export; cancelling this subscription stops it.
        run = AndroidChannels.exportRun
            .receiveBroadcastStream(_request(plan, name: job.outputPath))
            .listen(
              (message) => switch (_event(message)) {
                final ExportOutcome outcome => end(outcome),
                final event => events.add(event),
              },
              // The service refused to start, e.g. an export from before the
              // app was reopened still runs.
              onError: (Object error) => end(_refused(error)),
              onDone: end,
            );
      },
      onCancel: () {
        if (!events.isClosed) end();
      },
    );
    return events.stream;
  }

  @override
  void cancel() {
    if (!_running) return;
    unawaited(AndroidChannels.export.invokeMethod<void>('cancel'));
  }

  /// What `ExportRequest.from` (Kotlin) reads. Each clip spans its source
  /// from half a frame before its in point (ADR 0002) for its length on the
  /// track.
  static Map<String, Object?> _request(
    ExportPlan plan, {
    required String name,
  }) => {
    'name': name,
    'width': plan.size.width,
    'height': plan.size.height,
    'frameRateNumerator': plan.frameRate.numerator,
    'frameRateDenominator': plan.frameRate.denominator,
    'videoBitRate': plan.videoBitRate,
    'audioSampleRate': plan.audioSampleRate,
    'audioBitRate': plan.audioBitRate,
    'clips': [
      for (final clip in plan.clips)
        {
          'uri': clip.path,
          'startUs': clip.seek.inMicroseconds,
          'endUs': (clip.seek + clip.duration).inMicroseconds,
        },
    ],
  };

  /// An event as `ExportEvent.toMap` (Kotlin) sends it.
  static ExportEvent _event(Object? message) => switch (message) {
    {'event': 'progress', 'fraction': final double fraction} => ExportProgress(
      fraction.clamp(0, 1),
    ),
    {
      'event': 'succeeded',
      'uri': final String uri,
      'name': final String? name,
    } =>
      ExportSucceeded(uri, displayName: name),
    {
      'event': 'failed',
      'kind': final String kind,
      'detail': final String? detail,
    } =>
      ExportFailed(
        ExportFailure.values.asNameMap()[kind] ?? ExportFailure.failed,
        detail: detail,
      ),
    {'event': 'cancelled'} => const ExportCancelled(),
    _ => ExportFailed(
      ExportFailure.failed,
      detail: 'Unexpected export event: $message',
    ),
  };

  /// Why `ExportChannel.onListen` (Kotlin) refused to start.
  static ExportFailed _refused(Object error) => switch (error) {
    PlatformException(code: 'busy') => const ExportFailed(ExportFailure.busy),
    PlatformException(:final message, :final code) => ExportFailed(
      ExportFailure.cannotStart,
      detail: message ?? code,
    ),
    _ => ExportFailed(ExportFailure.cannotStart, detail: '$error'),
  };
}
