# ADR 0003 — How the Android app reaches videos

- Status: accepted (device behaviour to be confirmed by the owner, see CUTCAP-9 checklist)
- Date: 2026-11-07
- Ticket: CUTCAP-9

## Context

On Android the app never sees file paths. The system picker and "Share → cutcap" hand over `content://` URIs with a read grant, and a session restored after the app was killed must still open those videos. The editor, the session file, the players and the thumbnailer all key videos by `Source.path` and `SourceId`.

Options considered:

- **Copy every video into app storage** (what `file_selector_android` and `receive_sharing_intent` do to produce a path). Doubles the storage of multi-gigabyte phone videos and makes adding slow; rejected.
- **Ask for the video read permission up front and use MediaStore for everything.** Every user would see a permission prompt before adding a single video, and videos outside MediaStore (Drive, other document providers) would still need grants; rejected as the primary path.
- **Keep the URIs and the grants**, falling back to MediaStore only where a grant cannot be kept.

## Decision

- `Source.path` holds the URI string on Android and a file path on desktop. `SourceId` is that string, as before. Everything that reads a video (media_kit, which turns `content://` into an `fd://` itself; the Kotlin probe and thumbnailer) takes it as is. `Source.displayName` carries the name the system shows, because a URI's last segment is no file name; `Source.name` falls back to the last path segment. The session codec stores `displayName` within format version 1 and reads files saved without it.
- **Picking** uses `ACTION_OPEN_DOCUMENT` (`video/*`, multiple) from our own Kotlin (`VideoDocuments.kt`), not `file_selector`, whose Android implementation copies the file. Each picked URI's grant is persisted with `takePersistableUriPermission`. No permission is needed.
- **Sharing** (`ACTION_SEND`/`ACTION_SEND_MULTIPLE`, `video/*`): a share is read with cutcap's own access, so `ShareFilter` first drops (with a log line) every URI that is not `content://`, that belongs to one of cutcap's own providers, or that the intent does not grant read access to; otherwise a sender could make cutcap read its private files or media the sender cannot read. The activity is `singleTask`, so a share reaches the running editor through `onNewIntent` instead of starting a second instance. Its grant is persisted when the sender allowed it. Otherwise (the usual case: temporary grants) the app asks once for `READ_MEDIA_VIDEO` (API 33+) / `READ_EXTERNAL_STORAGE` (API 29–32) and swaps in the same video's MediaStore URI (`MediaStore.getMediaUri` for document URIs, else a lookup by display name and size). Without the permission the temporary URI is kept: the video works until the app is killed, then shows as "file not found".
- The share that starts the app goes through the same launch path as Windows "Open with" (`launchFilesProvider` → `EditorController.launch`), appended after the restored session; later shares stream in through `sharedVideosProvider` and are appended in order. A recreated activity or one reopened from Recents does not take its original share again.
- **Missing-source detection and thumbnail cache stamps** ask the Kotlin side (`exists` opens the URI for reading; `stamp` reads size and modification time from the provider).
- **Probe:** `MediaExtractor` and `MediaMetadataRetriever` report raw facts; Dart (`AndroidMediaProbe.parse`) derives the exact nominal rate from the first 600 presentation times (interval near the median, averaged, matched to a standard rate within 2 %, else kept to the millihertz), the average rate from the frame count, and the video bitrate (track, else container minus audio). A video whose track has no decoder on the device is rejected with its name.
- **Thumbnails:** `getScaledFrameAtTime(…, OPTION_CLOSEST_SYNC, …)` per ADR 0002.

## Consequences

- Android caps persisted grants per app (512 on Android 11+). Grants of sources no longer in the session are never released; a heavy user could reach the cap.
- If the user denies the video permission, shared (not picked) videos do not survive a restart.
- The MediaStore lookup by name and size can miss (renamed or edited copies) and then falls back to the temporary URI.
- `OPTION_CLOSEST_SYNC` thumbnails repeat the keyframe within a GOP; at single-frame zoom on long-GOP files the filmstrip shows the same frame for many cells.
