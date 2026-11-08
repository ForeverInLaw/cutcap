# Android export — device checklist

The Android export (Media3 in a foreground service, ADR 0004) does not run in CI. Before a release, run this on a phone with Android 10 or later and note any row that fails, with what you saw (a screenshot is enough). The scenarios are those of the Windows export integration test (`test/export/ffmpeg_export_integration_test.dart`), plus what only a phone has.

## Setup

- Install the APK under test: the `cutcap-android-debug` artifact of a green CI run (`gh run download <run> -n cutcap-android-debug`, then `adb install -r app-debug.apk`), or the release APK. A phone holding a build signed with another key needs `adb uninstall io.github.foreverinlaw.cutcap` first.
- Fixtures with the frame number burned in, made by the commands in ADR 0002 (`a_1080p30.mp4`, `b_720p25.mp4`, `c_portrait60_noaudio.mp4`, `d_vfr.mp4`, `e_720p25_rot90.mp4`). Copy them over with `adb push <file> /sdcard/Movies/cutcap-fixtures/`; the picker lists them under Movies. Record one more video with the phone's camera (usually variable rate, maybe HDR or HEVC).
- On the PC: ffmpeg/ffprobe. To check an export, pull it and probe it (PowerShell):

```powershell
adb pull "/sdcard/Movies/cutcap/<name>.mp4" .
ffprobe -v error -show_entries "stream=codec_name,width,height,r_frame_rate,avg_frame_rate,sample_rate,channels,duration:stream_side_data=rotation:format=duration" -of compact "<name>.mp4"
# The picture at a time, to read the burned-in frame number:
ffmpeg -v error -y -ss <seconds> -i "<name>.mp4" -frames:v 1 frame.png
```

Durations below are what the editor's status line shows for the sequence; "within a frame" means within 1/fps of it. Media3 drops frames but never repeats them, so a clip slower than the output rate keeps its own rate inside the file: `avg_frame_rate` may sit below the output rate, while durations still match.

## Output

| # | Steps | Expected |
| --- | --- | --- |
| 1 | Add a, b, c (in that order). Trim a to start a few frames in. Export. | Status shows progress, then "Saved a_1080p30-cut.mp4" with Open, Share, close. The gallery shows the video in Movies/cutcap at once. |
| 2 | Probe the file from row 1. | One h264 and one aac stream; 1920×1080; `r_frame_rate` 30/1; aac 48000 Hz, 2 channels; video and audio duration both equal the sequence duration within a frame. |
| 3 | Look at the file from row 1 in a player. | a's first frame is the one the editor showed at the start (read the burned number with the ffmpeg command at 0). b (1280×720) and the portrait c are fitted inside 1920×1080 with black bars, nothing cropped, c upright. Tone during a and b, silence during c, tone length matching its picture (no drift after c). |
| 4 | Clear, add c then a. Export and probe. | Portrait output: shown 1080×1920 upright (ffprobe may report 1920×1080 with rotation −90 or 90; that is fine). Rate 60. An audio stream exists: silence during c, a's tone after. |
| 5 | Clear, add d (variable rate) alone. Export and probe. | Duration 6.00 s within a frame. Nominal rate 25 or below (its average 25.28 rounds to 25; the 20 fps half stays at 20). Frames play in order across the 3 s rate change (burned numbers keep increasing). |
| 6 | Clear, add e (rotated 90°) first, then a. Export. | Output portrait (720×1280 as shown), e upright, a letterboxed below and above. |
| 7 | Clear, add your camera recording; split it twice and delete the middle. Export. | Plays upright with normal colours (an HDR recording comes out SDR, not washed out or dark); the cut lands where it was in the editor; sound in sync on both sides of the cut. |
| 8 | Cut points: put a alone on the track, trim to burned frames 61 to 150 (frame-step buttons), export, grab the first and last frame with the ffmpeg command (0 and duration − 1/30 s). | 61 and 150. |

## Running in the background

| # | Steps | Expected |
| --- | --- | --- |
| 9 | First export after install (Android 13+). | A one-time "allow notifications" prompt. Allow it. (If denied, the export still runs; rows 10–12 then have no notification to check.) |
| 10 | Make a long sequence (camera clip several times, a minute or more). Export, then press Home at once. | A notification "Exporting video" with a percentage that rises, and a Cancel action. After it ends: "Saved to Movies/cutcap" with the file name; tapping it plays the video. Back in cutcap the status shows the saved file. |
| 11 | Start the long export, press Home, then tap Cancel in the notification. | The notification disappears; no new file in Movies/cutcap (check the gallery or `adb shell ls /sdcard/Movies/cutcap`). Back in cutcap the status band is at rest and the edit is unchanged. |
| 12 | Start the long export, then swipe cutcap away in Recents. | The notification keeps counting and ends with "Saved to Movies/cutcap". Reopening cutcap shows the restored edit (its status does not know about that export). |
| 13 | Cancel in the app's status band while exporting. | Back to rest; nothing saved. |

## After the export

| # | Steps | Expected |
| --- | --- | --- |
| 14 | Tap Open after an export. | The video opens in the default player (or Android asks which app). |
| 15 | Tap Share. | The system share sheet with a preview of the video; sending it to a messenger or Drive delivers a playable mp4. |
| 16 | Export the same edit twice. | Two videos: the second is named `…-cut (1).mp4`, and the status names it so. The first is untouched. |

## Failures

| # | Steps | Expected |
| --- | --- | --- |
| 17 | Make a broken source on the PC: `ffmpeg -i a_1080p30.mp4 -c copy -movflags +faststart broken.mp4`, then cut it to half its size (`$b = [IO.File]::ReadAllBytes("broken.mp4"); [IO.File]::WriteAllBytes("half.mp4", $b[0..($b.Length / 2)])`), push `half.mp4`, add it, export. | Either "Export failed" with "Your edit is intact." and Media3's reason under it, plus an "Export failed" notification, and nothing in Movies/cutcap; or a shorter but playable video. Note which. After a failure Try again exports again; the edit is unchanged. |
| 18 | Start the long export, swipe cutcap away, reopen it while the notification still counts, and press Export. | "Export failed" with "An export is already running."; the running export is not disturbed. |
