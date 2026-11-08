# ADR 0004 — Android export with Media3 Transformer

- Status: accepted (device behaviour to be confirmed by the owner, see `docs/android-device-checklist.md`)
- Date: 2026-11-08
- Ticket: CUTCAP-10

## Context

ADR 0001 puts the Android export on Media3 Transformer in a foreground service; ADR 0002 fixes the output rules the Windows ffmpeg export follows. The Android build has to produce the same file from `content://` sources (ADR 0003), keep going when the user leaves the app, and save into Movies/cutcap without asking for storage permission. Media3 1.11.1 is the current stable release.

## Decision

- **One plan for both platforms.** Dart computes the `ExportPlan` (size, rate, bitrate, per-clip spans) and sends it over the `export/run` event channel; listening starts the export, cancelling the listen or the `cancel` method stops it. Kotlin (`ExportRequest`, `Media3Export`) only maps the plan onto Media3. Each clip is clipped from half a frame before its in point for its length on the track (ADR 0002 seek rule).
- **Composition:** one `EditedMediaItemSequence` with audio and video track types, so clips without audio get silence. Per clip a `FrameDropEffect` at the output rate and `Presentation.createForWidthAndHeight(W, H, LAYOUT_SCALE_TO_FIT)` (black bars). Media3 applies each source's rotation before the effects. Composition-level audio processors resample to 48 kHz and mix to stereo (constant gain for mono and stereo sources, constant power for 3 to 6 channels). HDR sources are tone-mapped to SDR with OpenGL, matching the BT.709 SDR output on Windows. H.264 and AAC through `DefaultEncoderFactory` (hardware codecs first), video at the planned bitrate, AAC at 192 kb/s.
- **Foreground service** (`ExportService`) of type `mediaProcessing` on Android 15+ and `dataSync` on Android 14 and older. Its notification shows progress and Cancel; when the export ends a separate notification says "Saved to Movies/cutcap" (tap plays the video) or "Export failed" with the reason. The notification permission is asked for on the first export (Android 13+); without it the export still runs, with the notification hidden.
- **Output:** Media3 writes into the app cache; the file is then copied into MediaStore (`Movies/cutcap`, pending until complete) and the cache copy deleted. MediaStore numbers a name that is taken instead of replacing the older video. Open (`ACTION_VIEW`) and Share (`ACTION_SEND` chooser) use the MediaStore URI. A failed or cancelled export leaves nothing in MediaStore and the edit untouched.
- **The export belongs to the process** (`ExportHub`), not to the activity. If the app's Flutter engine goes away mid-export (the app swiped away), the export still finishes and only its notification reports the result.

## Consequences

- Media3 can drop frames but not repeat them. A clip slower than the output rate keeps its own rate in the file (variable frame rate there), where ffmpeg would duplicate frames; duration and A/V sync are unaffected. Faster clips are dropped to the output rate like ffmpeg does.
- The clip spans start half a frame early for audio as well, so audio of a clip leads its picture by at most half a frame (17 ms at 30 fps).
- Media3 may encode portrait output as landscape with a rotation flag when the encoder prefers it; players show it upright, and ffprobe reports the coded size plus a rotation.
- The bitrate is a VBR target without the 1.5× peak cap ffmpeg gets.
- Saving copies the whole file once more; the cache needs room for one export.
- Sources with more than six audio channels fail the export (no default fold-down).
- Reopening the app while an earlier export still runs (after the engine was destroyed) shows an idle editor; a new export is refused as busy until the old one ends.
- Media3 encoder settings and effects are marked unstable API and may change between Media3 versions; the version is pinned in `android/app/build.gradle.kts`.
- None of this runs in CI; the owner checks it on a device with `docs/android-device-checklist.md`.
