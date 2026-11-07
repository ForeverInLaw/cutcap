# ADR 0001 — Flutter with platform-specific export engines

- Status: accepted
- Date: 2026-11-07

## Context

cutcap is a minimal frame-accurate video cutter for Android 10+ and Windows 10/11 x64 from one codebase. It needs continuous sequence preview with exact seeking, and re-encoded export with hardware H.264 that can concatenate clips of different resolution and frame rate. The repository is public and releases are distributed as binaries.

Options considered (status checked November 2026):

- **Flutter + ffmpeg-kit everywhere.** ffmpeg-kit is retired and its binaries removed; the surviving fork (`ffmpeg_kit_flutter_new`) has a single maintainer and no confirmed hardware H.264 encoder on Android.
- **Kotlin + Compose Multiplatform.** Ideal on Android (Media3), but Windows video playback options are immature or GPL-only, which makes the desktop preview the hardest part of the app.
- **Tauri 2.** WebView `<video>` scrubbing is not frame-accurate, Android cannot run an ffmpeg sidecar, and there is no precedent of a video editor on it; two native pipelines would be needed anyway.
- **Flutter UI + domain, media_kit preview, export behind an interface with one native engine per platform.**

## Decision

- Flutter (Dart 3) for UI, domain and state on both platforms.
- Preview through media_kit (libmpv) on both platforms, behind a `PreviewPlayer` interface.
- Export behind an `ExportEngine` interface with two implementations:
  - Windows: bundled `ffmpeg.exe` child process, hardware encoder probed in order nvenc → amf → qsv → mf → libx264.
  - Android: Media3 Transformer via a Kotlin platform channel in a foreground service.
- License the project GPL-3.0-or-later so stock GPL builds of FFmpeg and libmpv can be redistributed.

## Consequences

- Two export implementations must stay behaviourally equivalent; the Windows one is covered by real-export integration tests in CI, the Android one by a manual device checklist.
- media_kit's frame-accurate seeking is unverified; a spike validates it first. If it fails on Android, preview there moves to ExoPlayer behind `PreviewPlayer` without touching the domain or UI.
- Choosing GPL rules out a later closed-source or permissively licensed release without replacing FFmpeg/libmpv builds; the engine and player interfaces keep that swap local.
- Media3 `CompositionPlayer` is experimental and not used; preview orchestrates per-clip playback in Dart and accepts a hitch at clip boundaries.
