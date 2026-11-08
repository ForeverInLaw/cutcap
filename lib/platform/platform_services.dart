import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../export/android_export_engine.dart';
import '../export/export_engine.dart';
import '../export/ffmpeg_export_engine.dart';
import '../media/android_media_probe.dart';
import '../media/android_thumbnail_source.dart';
import '../media/ffmpeg_thumbnail_source.dart';
import '../media/ffprobe_media_probe.dart';
import '../media/media_probe.dart';
import '../media/media_tools.dart';
import '../media/thumbnail_cache.dart';
import '../media/thumbnail_source.dart';
import 'android_documents.dart';
import 'android_exports.dart';
import 'incoming_files.dart';
import 'open_file.dart';

/// Everything that differs between the platforms cutcap runs on, chosen
/// once at the composition root: `main` overrides [platformServicesProvider]
/// with [PlatformServices.android] or [PlatformServices.desktop]. The
/// editor's providers read their piece from it; tests override those
/// providers one by one, or this one whole.
final class PlatformServices {
  const PlatformServices({
    required this.mediaProbe,
    required this.thumbnailSource,
    required this.thumbnailStamp,
    required this.pickVideos,
    required this.sourceExists,
    required this.sharedVideos,
    required this.launchFiles,
    required this.exportEngine,
    required this.saveLocation,
    required this.openFile,
    required this.shareFile,
    required this.acceptsFileDrop,
  });

  /// Android: videos are `content://` URIs reached over the Kotlin
  /// channels (ADR 0003), exports run on Media3 (ADR 0004) and land in
  /// Movies/cutcap.
  factory PlatformServices.android() => PlatformServices(
    mediaProbe: const AndroidMediaProbe(),
    thumbnailSource: const AndroidThumbnailSource(),
    thumbnailStamp: AndroidDocuments.stamp,
    pickVideos: AndroidDocuments.pick,
    sourceExists: AndroidDocuments.exists,
    sharedVideos: AndroidDocuments.shared(),
    // The share that started the app takes the place of arguments.
    launchFiles: (_) => AndroidDocuments.launchShares(),
    exportEngine: AndroidExportEngine(),
    // Always the suggested name, in Movies/cutcap; there is no dialog.
    saveLocation: Future.value,
    openFile: (uri) => unawaited(AndroidExports.open(uri)),
    shareFile: (uri) => unawaited(AndroidExports.share(uri)),
    acceptsFileDrop: false,
  );

  /// Windows, and the desktop tests run on: file paths, and the ffmpeg
  /// next to the app or on `PATH` for thumbnails and export.
  factory PlatformServices.desktop() {
    final ffmpeg = const MediaToolLocator().find(MediaTool.ffmpeg);
    return PlatformServices(
      mediaProbe: const FfprobeMediaProbe(),
      thumbnailSource: ffmpeg == null ? null : FfmpegThumbnailSource(ffmpeg),
      thumbnailStamp: fileStamp,
      pickVideos: _pickVideos,
      sourceExists: (path) => File(path).exists(),
      sharedVideos: const Stream.empty(),
      launchFiles: (arguments) async => incomingFiles(arguments),
      exportEngine: ffmpeg == null
          ? null
          : FfmpegExportEngine(ffmpegPath: ffmpeg),
      saveLocation: _askSaveLocation,
      openFile: openWithDefaultApp,
      shareFile: null,
      acceptsFileDrop: true,
    );
  }

  /// Reads the facts of a video.
  final MediaProbe mediaProbe;

  /// Renders filmstrip thumbnails; null when it cannot (no ffmpeg), and the
  /// filmstrip keeps its solid frames.
  final ThumbnailSource? thumbnailSource;

  /// Tells a video's versions apart for the thumbnail cache.
  final Future<VideoStamp> Function(String path) thumbnailStamp;

  /// Asks the user for videos; paths (Android: content URIs) come back in
  /// the order the picker returns them. The Windows dialog returns them in
  /// its own (shell) order, not the order they were clicked in.
  final Future<List<String>> Function() pickVideos;

  /// Whether a source is still there (on Android, still readable).
  final Future<bool> Function(String path) sourceExists;

  /// Videos shared into the running app, a batch per share (Android
  /// "Share → cutcap"); never emits on desktop.
  final Stream<List<String>> sharedVideos;

  /// The files the app was started with, from its command-line [arguments]
  /// (Windows "Open with"; on Android the share that started it).
  final Future<List<String>> Function(List<String> arguments) launchFiles;

  /// Exports for this app session (kept, so the encoder is probed once);
  /// null when there is nothing to export with (no ffmpeg).
  final ExportEngine? exportEngine;

  /// Where an export goes, given the suggested name; null when the user
  /// backs out.
  final Future<String?> Function(String suggestedName) saveLocation;

  /// Opens a finished export (a path, on Android its URI) with the
  /// system's default app.
  final void Function(String path) openFile;

  /// Hands a finished export to the system share sheet; null where there
  /// is none, which also hides Share.
  final void Function(String path)? shareFile;

  /// Whether files can be dropped onto the window (from Explorer).
  final bool acceptsFileDrop;
}

/// The [PlatformServices] of this run. `main` picks them for the device;
/// without that (tests) they are the desktop ones.
final platformServicesProvider = Provider<PlatformServices>(
  (ref) => PlatformServices.desktop(),
);

Future<List<String>> _pickVideos() async {
  const videos = XTypeGroup(
    label: 'video',
    extensions: ['mp4', 'mov', 'm4v', 'mkv', 'webm', 'avi', '3gp'],
    mimeTypes: ['video/*'],
    uniformTypeIdentifiers: ['public.movie'],
  );
  final files = await openFiles(acceptedTypeGroups: const [videos]);
  return [for (final file in files) file.path];
}

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
