# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

One person, the owner, editing their own recordings. On the phone they cut in portrait, often one-handed, right after recording or before sending a clip to someone. On the Windows PC they work with mouse and keyboard on longer recordings and expect editor-standard shortcuts.

## Product Purpose

cutcap does exactly four things to video: cut, remove, join and reorder, with frame accuracy, and exports a normal mp4 that plays everywhere. It exists because full editors bury that job under tracks, effects, accounts and watermarks, while lossless cutters snap to keyframes and refuse to join mixed sources. Success is opening a video, making the cuts, and having a shareable file in under a minute without touching a setting.

## Positioning

Frame-accurate cutting and joining of mixed-resolution, mixed-frame-rate sources with no settings at all: the output always follows the first clip, every export re-encodes on the hardware encoder, and the same tool behaves the same way on an Android phone and a Windows PC.

## Operating Context

- A single editor screen: preview on top, one magnetic track at the bottom. No project browser, no menus of settings.
- Sources come from the system file picker, Explorer drag-and-drop or "Open with" on Windows, and the share sheet on Android.
- Work happens offline. The current edit autosaves and returns on next launch; there are no project files.
- Export goes to a Save-as location on Windows and to Movies/cutcap on Android, then the result is opened or shared immediately.

## Capabilities and Constraints

- Built with Flutter from one codebase for Android 10+ phones and Windows 10 22H2+/11 x64 desktops. Platform records `android` because Material 3 is the shared component language; the same design language ships unchanged on Windows, where only layout and input (mouse, keyboard shortcuts, Ctrl+wheel zoom) adapt. No per-OS restyling.
- Editing: split at playhead, delete with ripple, drag to reorder, trim clip edges within source bounds, undo/redo, clear. Frame-step controls next to the playhead.
- Preview: continuous sequence playback with exact seeking; a short hitch at clip boundaries is accepted. An exact seek can take up to about one second on long-GOP 1080p60 sources, so scrubbing must stay responsive while the frame catches up.
- Export: H.264 + AAC mp4, geometry and frame rate from the first clip, others letterboxed, progress with cancel; on Android it continues in a foreground notification.
- States the screen must carry: empty (no clips), loading thumbnails, playing, scrubbing, trimming, dragging, exporting, export done, export failed, undecodable file, clip whose source file is missing ("file not found", kept but skipped at export).
- UI language follows the system: Russian or English.
- Out of scope: multiple tracks, effects, transitions, audio editing, export settings, project files, accounts.

## Brand Commitments

- Name: "cutcap", written lowercase. No logo, palette or typeface exists yet.
- Open source under GPL-3.0-or-later; no ads, accounts or upsell.

## Evidence on Hand

No screenshots, sample footage, logo or marketing material exist. Thumbnails and demo clips in any mock are synthetic and must be labelled so.

## Product Principles

- Four verbs only: every control on screen serves cut, remove, join or reorder.
- Precision over speed of feel: the frame shown is the frame exported.
- No settings: decisions the product can make from the first clip, it makes.
- Same tool on both devices: one model, one layout logic, adapted to touch or keyboard.
- Edits are cheap: undo is always one action away and nothing destroys work.

## Accessibility & Inclusion

Baseline: WCAG AA contrast, visible keyboard focus on Windows, touch targets of at least 48 dp on Android, and the system reduce-motion setting respected.
