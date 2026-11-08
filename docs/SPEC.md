# cutcap v1 — Spec

## Problem Statement

I want to quickly trim, cut out, join and reorder pieces of video on my Android phone and my Windows PC. Existing editors are either heavyweight (multi-track timelines, effects, accounts, ads, watermarks) or lossless cutters that can only cut on keyframes and refuse to join videos with different resolution or codec. I need one small tool that does exactly "cut, remove, join, reorder" with frame accuracy and exports a normal mp4, the same way on both devices.

## Solution

cutcap is a minimal, offline video cutter for Android 10+ and Windows 10 22H2+/11 x64, built from one Flutter codebase. The user adds one or more videos; they appear as clips on a single magnetic track. The user splits clips at the playhead, deletes unwanted pieces, trims clip edges, and drags clips to reorder them, with undo/redo for every edit. The whole sequence previews continuously. Export always re-encodes with a hardware encoder into mp4 (H.264 + AAC), with frame-accurate cuts, matching the first clip's resolution, orientation and frame rate and letterboxing the rest. The current session is autosaved and restored on next launch. The app is open source (GPL-3.0-or-later), distributed as a Windows installer and an Android APK via GitHub Releases.

## User Stories

### Adding media

1. As a user, I want to pick one or more videos from a system file picker, so that I can start editing without learning a project system.
2. As a user, I want videos picked together to be added in the order I selected them, so that the sequence matches my intent without extra dragging.
3. As a Windows user, I want to drag video files from Explorer into the window, so that adding media is as fast as possible.
4. As an Android user, I want to share a video from the gallery into cutcap, so that I can start editing directly from where I found the video.
5. As a Windows user, I want cutcap to appear in "Open with" for video files, so that I can open a video in it from Explorer.
6. As a user, I want newly added videos to be appended to the end of the sequence, so that adding never disturbs edits I already made.
7. As a user, I want a clear error when a file cannot be decoded on my device, so that I know the file is the problem and not my edit.
8. As a user, I want rotated phone recordings to display upright, so that portrait videos look right in the editor.

### Timeline

9. As a user, I want all clips laid out on one track, back to back with no gaps, so that what I see is exactly what will be exported.
10. As a user, I want each clip shown as a filmstrip of thumbnails, so that I can recognise content without playing it.
11. As a user, I want to zoom the timeline with pinch (Android) or Ctrl+wheel (Windows), so that I can work both on the whole sequence and on single frames.
12. As a user, I want to scrub the playhead along the timeline and see the frame under it in the preview, so that I can find the exact cut point.
13. As a user, I want the playhead to snap to clip boundaries, so that I can land on cuts precisely.
14. As a user, I want frame-step buttons next to the playhead, so that I can hit the exact frame on a touch screen.
15. As a user, I want to see the total sequence duration and the playhead time, so that I know how long the result will be.

### Editing

16. As a user, I want to split the clip under the playhead into two clips, so that I can isolate a fragment.
17. As a user, I want to delete a selected clip and have the following clips close the gap, so that removing a fragment is one action.
18. As a user, I want to cut a fragment out of the middle of a video by splitting twice and deleting the middle, so that I can remove unwanted parts.
19. As a user, I want to drag a clip to a new position in the sequence, so that I can reorder fragments.
20. As a user, I want to drag a clip's left or right edge to trim its in or out point, so that I can fine-tune cuts without re-splitting.
21. As a user, I want trimming to snap to frames and the preview to show the frame under the dragged edge, so that trimming is precise.
22. As a user, I want trimming to stop at the bounds of the source video, so that I cannot create invalid clips.
23. As a user, I want to undo any edit, so that mistakes are cheap.
24. As a user, I want to redo an undone edit, so that I can step back and forth while deciding.
25. As a user, I want to clear the whole sequence and start over, so that I can begin a new edit quickly.
26. As a user, I want clips from different source videos to mix freely in the sequence, so that I can join recordings from different devices.

### Preview

27. As a user, I want to play the whole sequence continuously across clip boundaries, so that I can check the result before exporting.
28. As a user, I want a short hitch at clip boundaries in preview to be acceptable, so that the app stays simple; the export itself is seamless.
29. As a user, I want play/pause to toggle from anywhere, so that reviewing is quick.

### Keyboard (Windows)

30. As a Windows user, I want Space to play/pause, so that I can review without the mouse.
31. As a Windows user, I want S to split at the playhead, so that cutting is a single keystroke.
32. As a Windows user, I want Delete to remove the selected clip, so that removing is a single keystroke.
33. As a Windows user, I want Left/Right arrows to step one frame, so that I can find exact cut points.
34. As a Windows user, I want J/K/L for reverse/pause/forward playback, so that I can use familiar editor shortcuts.
35. As a Windows user, I want Ctrl+Z / Ctrl+Shift+Z (and Ctrl+Y) for undo/redo, so that standard shortcuts work.

### Export

36. As a user, I want to export the sequence to an mp4 file with H.264 video and AAC audio, so that the result plays everywhere and can be sent through any messenger.
37. As a user, I want cuts in the export to be frame-accurate, so that the result matches what I saw in the editor.
38. As a user, I want the output resolution, orientation and frame rate to follow the first clip, so that I never have to pick settings.
39. As a user, I want clips with a different size or orientation to be fitted with black bars, so that nothing is cropped.
40. As a user, I want clips without audio to contribute silence of the right length, so that audio stays in sync after them.
41. As a user, I want the export bitrate chosen automatically close to the source, so that quality is preserved without settings.
42. As a user, I want export to use the hardware encoder of my device, so that it is fast and does not drain the battery.
43. As a user, I want to see export progress and be able to cancel, so that I stay in control of long exports.
44. As an Android user, I want export to continue when I leave the app, with progress and a cancel button in a notification, so that long exports are not killed.
45. As an Android user, I want the result saved to Movies/cutcap so that it appears in the gallery immediately.
46. As a Windows user, I want a "Save as" dialog to choose where the export goes, so that I control the location.
47. As a user, I want "Open" and (on Android) "Share" buttons after export, so that I can use the result right away.
48. As a user, I want a clear message if export fails, so that I know my edit is still intact and I can retry.

### Session

49. As a user, I want my current edit autosaved, so that I do not lose work if the app is closed or killed.
50. As a user, I want the last session restored on launch, so that I can continue where I left off.
51. As a user, I want clips whose source file disappeared to be marked "file not found" and excluded from export while staying in the session, so that one missing file does not destroy my edit.

### Language and distribution

52. As a user, I want the UI in Russian or English following my system language, so that it feels native.
53. As a Windows user, I want a per-user installer that needs no admin rights, with a Start menu shortcut, so that installation is painless.
54. As an Android user, I want to install a signed APK that updates over the previous version, so that upgrades keep my install.
55. As a user, I want releases published on GitHub with both artifacts, so that I can download the latest build on either device.

## Implementation Decisions

- **Platform targets:** Android 10+ (API 29), Windows 10 22H2+/11 x64. No ARM Windows, no iOS/macOS/Linux builds.
- **Framework:** Flutter (Dart 3). Single UI and single domain model for both platforms; one adaptive layout (preview on top, timeline at bottom), touch-first with keyboard shortcuts on desktop. Visual design is produced through the `impeccable` skill.
- **License:** GPL-3.0-or-later, so stock GPL builds of FFmpeg and libmpv can be bundled. Third-party notices list FFmpeg and mpv sources.
- **Domain module (`EditorSession`)** — pure Dart, no Flutter imports. Immutable value types: a source (id, path, duration, resolution, rotation, frame rate, has-audio), a clip (source id, in, out), an edit list (ordered clips). Commands: add sources, split at sequence time, remove clip, move clip to index, trim clip edge to time, clear, undo, redo. Queries: clips, total duration, mapping from sequence time to (clip, source time) and back. Undo/redo is a stack of edit-list snapshots. No code generation; sealed classes and records.
- **Time model:** times are integer microseconds; trims and splits snap to the source's frame grid.
- **Application state:** Riverpod 3 `Notifier`s wrapping `EditorSession`; widgets read narrowly via `select`.
- **Preview (`PreviewPlayer` interface):** media_kit (libmpv) on both platforms with exact seeking. Sequence playback is orchestrated in Dart: when the position reaches a clip's out point, open the next clip's source and seek to its in point. A hitch at boundaries is accepted. The interface exists so Android can switch to ExoPlayer if media_kit seeking proves inadequate there.
- **Thumbnails:** generated asynchronously per source and cached; mechanism is decided during the spike.
- **Export (`ExportEngine` interface):** input is an edit list plus output target; output is a stream of progress events ending in success, failure or cancellation; supports cancel.
  - **Windows implementation:** bundled `ffmpeg.exe` run as a child process; a single filter graph trims, scales/pads to the first clip's geometry, normalises fps, inserts silence for audio-less clips and concatenates. Encoder chosen by probing in priority order `h264_nvenc` → `h264_amf` → `h264_qsv` → `h264_mf` → `libx264`. Progress parsed from `-progress`.
  - **Android implementation:** Media3 Transformer via a platform channel (Kotlin): a Composition with one sequence of clipped media items, a Presentation effect fitting to the first clip, H.264/AAC output via MediaCodec. Runs in a foreground service with a progress notification and cancel action. Output written through MediaStore to Movies/cutcap.
- **Output rules:** mp4, H.264 + AAC; resolution, orientation and fps from the first clip; variable-frame-rate first clip uses its average fps rounded to the nearest standard rate (24/25/30/50/60); bitrate approximates the source; others letterboxed; rotation metadata honoured.
- **Session persistence:** the current edit list and source references are autosaved locally after each edit and restored on launch; no project files. Missing sources are flagged and skipped at export.
- **Input:** whatever the platform decoders handle (mp4/mov/mkv/webm with H.264/HEVC/VP9/AV1 where supported); undecodable files produce a clear error.
- **Localisation:** `flutter gen-l10n` with `ru` and `en`, system locale.
- **Distribution:** Windows installer built with Inno Setup (per-user into LocalAppData, Start menu shortcut, "Open with" registration, unsigned, no auto-update). Android APK signed with a persistent release keystore held in GitHub Secrets.
- **CI (GitHub Actions, public repo):**
  - Every push/PR: format check, analyze and tests on Ubuntu; platform builds only when relevant paths change.
  - Push to main: Windows and Android builds, artifacts kept 7 days.
  - Tag `v*`: both builds and a GitHub Release with the installer and the APK.
  - Optimisation: `concurrency` with cancel-in-progress; cheap jobs on Ubuntu, Windows runner only for the exe/installer; caches for Flutter SDK, pub, Gradle (setup-gradle with configuration cache), FFmpeg binary (keyed by version + sha256) and Inno Setup; exact pinned Flutter and FFmpeg versions; third-party actions pinned by SHA; minimal `GITHUB_TOKEN` permissions.
- **Repository language:** English for code, docs, comments and commits.
- **Work order:** (1) spike: media_kit frame-accurate seek and an ffmpeg concat export on Windows; (2) UI design via `impeccable`; (3) Windows tracer bullet — open two files, split, reorder, export; (4) Android slice — Media3 engine, foreground service, touch gestures, share intent.

## Testing Decisions

- Good tests exercise external behaviour through a public seam and survive refactors of internals. No tests of private structure, no snapshot tests of generated command lines, no smoke tests for their own sake.
- **Seam 1 — `EditorSession`:** unit tests (written test-first) drive commands and assert on observable state: clip order, in/out points, total duration, sequence↔source time mapping, frame snapping, trim bounds, undo/redo round trips.
- **Seam 2 — `ExportEngine` (Windows/ffmpeg implementation):** integration tests run a real export on Ubuntu CI with system ffmpeg against generated fixtures (`testsrc` clips with different resolutions and frame rates, one without audio), then assert with `ffprobe`: duration equals the sum of clips within one frame, resolution and fps match the first clip, an audio stream exists. On runners without GPUs the encoder probe falls through to `libx264`.
- **Android `ExportEngine` (Media3):** not run in CI; verified with a manual on-device checklist using the same scenarios.
- **UI widgets** are tested only where they carry gesture or layout logic: the timeline gestures (scrub, trim, reorder, pinch, edge scroll) and whether the phone top bar fits at 360 dp and large text. There are no golden or snapshot tests.
- **Not tested:** `PreviewPlayer`.
- **Prior art:** none — greenfield repository.

## Out of Scope

- Multiple tracks, overlays, titles, transitions, filters, colour correction, speed changes.
- Any audio editing: mute, volume, separate music tracks, audio-only clips.
- Lossless (stream-copy) or smart-render export; output format, codec or quality settings; HEVC output.
- Project files or multiple saved projects; cloud sync; accounts.
- Clip duplication.
- Crop, rotate, or fill modes for mismatched clips (always fit with black bars).
- App store distribution, code signing for Windows, auto-update.
- iOS, macOS, Linux, ARM Windows; Android below 10.

## Further Notes

- The spike exists to retire the two biggest technical risks before design work: frame-accurate seeking through media_kit on both platforms, and a mixed-resolution concat export via ffmpeg. If seeking on Android is inadequate, preview there switches to ExoPlayer behind `PreviewPlayer`.
- `CompositionPlayer` (Media3) is still experimental as of Media3 1.10, so it is not used for preview.
- ffmpeg-kit is retired; it is deliberately not used.
- The release keystore is created by the owner; the build only reads it from secrets.
