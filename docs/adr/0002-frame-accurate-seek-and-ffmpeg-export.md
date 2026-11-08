# ADR 0002 — Frame-accurate seek and the ffmpeg export command

- Status: accepted (Android seek verification pending, see below)
- Date: 2026-11-07
- Spike: CUTCAP-2. Prototype code discarded.

## Context

ADR 0001 left two risks open: whether media_kit (libmpv) lands on an exact frame when seeking, and whether one ffmpeg invocation on Windows can produce the export the spec's output rules demand from mixed sources. The spike also had to choose the thumbnail mechanism and pin toolchain versions.

Dev machine: Windows 11, Ryzen 7 6800H (Radeon 680M iGPU) + RTX 3070 Ti Laptop, ffmpeg 9.0.2 (gyan.dev full build), Flutter 3.44.8. No Android device.

Fixtures are synthetic clips with the frame index burned in, so every check reads an objective number:

```sh
DT="drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='%{frame_num}':fontsize=h/6:fontcolor=white:box=1:boxcolor=black:x=(w-tw)/2:y=(h-th)/2"
X="-c:v libx264 -preset veryfast -bf 2 -pix_fmt yuv420p"
ffmpeg -f lavfi -i testsrc2=s=1920x1080:r=30:d=10 -f lavfi -i sine=f=440:sample_rate=48000:d=10 -vf "$DT" $X -g 300 -c:a aac -shortest a_1080p30.mp4
ffmpeg -f lavfi -i testsrc2=s=1280x720:r=25:d=10  -f lavfi -i sine=f=880:sample_rate=44100:d=10 -vf "$DT" $X -g 250 -c:a aac -shortest b_720p25.mp4
ffmpeg -f lavfi -i testsrc=s=1080x1920:r=60:d=6 -vf "$DT" $X -g 360 c_portrait60_noaudio.mp4
# VFR: 0-3 s at 30 fps, 3-6 s at 20 fps -> r_frame_rate 60/1, avg_frame_rate 2250/89 (25.28)
ffmpeg -f lavfi -i testsrc2=s=1280x720:r=60:d=6 -f lavfi -i sine=f=660:sample_rate=48000:d=6 \
  -vf "select='if(lt(t,3),not(mod(n,2)),not(mod(n,3)))',$DT" -fps_mode vfr $X -g 300 -c:a aac -shortest d_vfr.mp4
ffmpeg -display_rotation:v:0 90 -i b_720p25.mp4 -c copy e_720p25_rot90.mp4
```

GOPs are deliberately long (6–10 s, a single keyframe) so a seek must decode forward from the keyframe to land on the target.

## Findings

### Seeking in media_kit (Windows)

A Flutter Windows app (media_kit 1.2.6, Debug build) opened each fixture paused, sought to target frames in non-monotonic order (first, last, both sides of the VFR rate change, far from the keyframe), waited until mpv's `seeking` was `no` and `time-pos` was stable, captured `Player.screenshot()` (mpv `screenshot-raw video`, decoded frame at source size) and matched it to the nearest of all source frames extracted by ffmpeg (96×54 grey MSE).

| Seek target for frame *k* (pts *tₖ*) | Result (34 targets over 4 clips) |
| --- | --- |
| `player.seek(tₖ)` | 34/34 exact |
| `seek tₖ absolute+exact` via `NativePlayer.command` | 34/34 exact |
| `player.seek(tₖ − ½ frame)` | 30/34 exact; the 4 misses were all *k* = 0, where the negative target made mpv seek from the end |
| `player.seek(tₖ + ½ frame)` | 4/34; every other target showed *k*+1 |
| 30 un-awaited seeks, then `player.seek(tₖ)` | 4/4 exact (latest seek wins) |

- media_kit already sets `hr-seek=yes` and `hr-seek-framedrop=no` (`NativePlayer` defaults), and `Player.seek` issues `seek <s> absolute` with **millisecond** precision (`inMilliseconds / 1000`).
- mpv hr-seek displays **the first frame whose pts ≥ target**. Any target in (*tₖ₋₁*, *tₖ*] lands on frame *k*.
- Seek-to-settle latency on these worst-case GOPs: median 170–620 ms, max 970 ms per seek (1080p/60p portrait slowest).
- `frame-step`/`frame-back-step` gave inconsistent results when polled this way; they are not needed because the domain computes frame times.

### Export (ffmpeg, Windows)

- `-ss` as an input option is decode-accurate and keeps the first frame with pts ≥ the value. `-ss 2.033333` (frame 61 truncated to µs) gave frame 61, `-ss 2.034` gave 62, so a value rounded the wrong way by under 1 µs drops a frame. Passing **frame start − ½ source frame** removes that hazard and matches mpv's rule.
- Run 1, first clip 1080p30: A[61,151) + B 720p25 [25,100) + C 1080×1920@60 without audio [30,150) + E 720p25 rotated 90° [0,25). Output for nvenc, amf, mf and libx264 alike: 1920×1080, `avg_frame_rate=30/1`, 270 frames, video and audio both 9.000000 s, AAC 48 kHz stereo, H.264 High. Burned numbers at output frames 0/89/90/179/180/239/240/269 read 61/150/25/99/30/148/0/24: cuts exact, portrait and rotated clips pillarboxed upright, silence (−90 dB) during C.
- Run 2, VFR first clip (avg 25.28 → 25): D[60,130) + A[0,60) + C[0,60) → 1280×720, `25/1`, 150 frames, 6.000 s, D's frames 60…129 intact across the 30→20 fps change.
- When the source rate differs from the output rate, each output frame shows the latest source frame inside its slot: the first output frame of C at 60→25 shows source frame 1, not 0. Deviation stays under one output frame; same-rate clips are frame-for-frame exact.
- Audio/video drift: video is snapped to whole output frames per clip (`trim=end_frame`), so audio is padded or cut to exactly the matching sample count (`apad=whole_len` + `atrim=end_sample`). Without that, per-clip rounding accumulates A/V drift.
- Encoders format-negotiate differently: `h264_mf -hw_encoding 1` rejects `yuv420p` ("format negotiation failed") and only accepts `nv12`; its software MFT accepts both, so a probe without `-hw_encoding` reports a false positive. Every encoder accepts `nv12`. `h264_mf` rejects `-profile:v high` (needs `100`) and defaults to Baseline; AMF defaults to Main.
- Colour tags differed by encoder (mf tagged BT.709, the others untagged, which decoders may read as BT.601). Setting them with `setparams` in the filter graph tags all four outputs BT.709 TV range; the `-colorspace/-color_*` output options were only partly applied (primaries and transfer stayed `unknown`).
- Wall time for the 9 s 1080p export: 2.0–2.8 s for every encoder (decode and filters dominate at this length). `-progress` reports `out_time_us` and ends with `progress=end`.

Encoder probe on this machine, 5-frame 256×256 `nv12` encode with the export's own options:

| Encoder | Result | Time |
| --- | --- | --- |
| `h264_nvenc` | OK | 420–530 ms |
| `h264_amf` | OK | 360–410 ms |
| `h264_qsv` | FAIL, `Error creating a MFX session: -9` (no Intel GPU) | 350–410 ms |
| `h264_mf` | OK | 230–560 ms |
| `libx264` | OK | 135–150 ms |

### Thumbnails

20 filmstrip thumbnails from a 60 s 1080p30 clip (GOP 1 s), one ffmpeg process with one `-ss T -i src` input per thumbnail, `scale=-2:96`, JPEG: 840 ms with accurate seek, 930 ms with `-noaccurate_seek`. Keyframe-only seeking buys nothing and shows the wrong frame on long-GOP sources.

## Decisions

1. **Seek rule (both platforms, preview and export):** to show or cut at frame *k*, use `max(0, tₖ − ½·frameDuration)`, where `frameDuration` comes from the source's nominal rate. The same value goes to `Player.seek` and to ffmpeg `-ss`. Exact seeks are always used; scrubbing issues them latest-wins without awaiting each one.
2. **Windows preview stays on media_kit.** Seeking is frame-exact there.
3. **Output geometry and rate:** display size of the first clip (after rotation; ffmpeg autorotates inputs, the output carries no rotation flag). Output rate is the first clip's `r_frame_rate` when it is constant. When the first clip is VFR (`avg_frame_rate` differs from `r_frame_rate` by more than 0.1 %), the rate is `avg_frame_rate` rounded to the nearest of 24/25/30/50/60. Per clip, output frames are `Nᵢ = round(durᵢ × fps)`; audio samples are `Sᵢ = round(ΣN₁..ᵢ × 48000 / fps) − round(ΣN₁..ᵢ₋₁ × 48000 / fps)`, cumulative so 29.97-style rates do not drift.
4. **Bitrate:** `B` = first clip's video stream `bit_rate` (or format `bit_rate` minus audio), clamped to 1–50 Mb/s; `-maxrate 1.5B -bufsize 2B`. AAC 192 kb/s, 48 kHz stereo.
5. **Encoder probe:** at first export, try `h264_nvenc → h264_amf → h264_qsv → h264_mf → libx264` with a 5-frame 256×256 `nv12` encode using the exact per-encoder options below, and take the first that exits 0. Cache the result for the app session. Never use `-encoders` as the signal.
6. **Thumbnails** go behind a `ThumbnailSource` interface:
   - Windows: the bundled `ffmpeg.exe`, one process per source, accurate `-ss` per thumbnail, JPEG at 96 px height, cached on disk per source.
   - Android: `MediaMetadataRetriever.getScaledFrameAtTime(us, OPTION_CLOSEST_SYNC, w, h)` (API 27+) on a background thread in the Kotlin plugin that hosts the Media3 export. A filmstrip does not need exact frames.
   - Neither uses a media_kit screenshot, which would need a second libmpv instance with video output and pay 0.2–1 s per exact seek, serialised.

### Export command template

One input per clip (the same source may appear several times). `{…}` are computed per export. Clip *i* without audio replaces its `[i:a:0]` chain with `anullsrc=r=48000:cl=stereo,$A,atrim=end_sample={Sᵢ}[aᵢ]`.

```sh
V="scale={W}:{H}:force_original_aspect_ratio=decrease:out_color_matrix=bt709:out_range=tv,\
pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps={FPS},format=nv12,\
setparams=range=tv:colorspace=bt709:color_primaries=bt709:color_trc=bt709"
A="aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo"

ffmpeg -hide_banner -nostdin -y -loglevel error -nostats -progress pipe:1 \
  -ss {in₀ − ½f₀} -i {src₀}  …  -ss {inₙ − ½fₙ} -i {srcₙ} \
  -filter_complex "\
[0:v:0]trim=duration={dur₀},setpts=PTS-STARTPTS,$V,tpad=stop_mode=clone:stop=-1,trim=end_frame={N₀}[v0];\
[0:a:0]atrim=duration={dur₀},asetpts=PTS-STARTPTS,$A,apad=whole_len={S₀},atrim=end_sample={S₀}[a0];\
…\
[v0][a0]…[vn][an]concat=n={n+1}:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v {ENC} {ENC_OPTS} -b:v {B}k -maxrate {1.5B}k -bufsize {2B}k \
  -c:a aac -b:a 192k -movflags +faststart {out}.mp4
```

| `{ENC}` | `{ENC_OPTS}` |
| --- | --- |
| `h264_nvenc` | `-preset p5 -rc vbr -profile:v high` |
| `h264_amf` | `-quality balanced -rc vbr_peak -profile:v high` |
| `h264_qsv` | `-preset medium -profile:v high` (not run here) |
| `h264_mf` | `-hw_encoding 1 -rate_control pc_vbr -profile:v 100` |
| `libx264` | `-preset veryfast -profile:v high` |

### Pinned versions

| Component | Pin |
| --- | --- |
| Flutter | 3.44.8 stable (Dart 3.12.2, framework revision `058e0af2c2`) |
| `media_kit` | 1.2.6 |
| `media_kit_video` | 2.0.1 |
| `media_kit_libs_video` | 1.0.7 (resolves `media_kit_libs_windows_video` 1.0.11, which bundles libmpv `mpv-dev-x86_64-20230924-git-652a1dd`, and `media_kit_libs_android_video` 1.3.8) |
| FFmpeg (Windows bundle and CI) | gyan.dev 9.0.2 essentials, GPLv3, static: `https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.7z`, 35 430 500 bytes, sha256 `4705843ccaaf54257c16ad90f3e952ece33c17df964ecf7bfdbb0f49c7171077`. Ship `bin/ffmpeg.exe` and `bin/ffprobe.exe`. |

Pub versions are pinned exactly (no caret). The FFmpeg sha256 is GitHub's published asset digest, and a real download matched it (CUTCAP-6); `tool/fetch_ffmpeg.ps1` verifies it on every download, and CI keys the cache on version + sha256. Essentials includes libx264, nvenc, amf, libvpl (QSV) and mediafoundation per gyan.dev's component list. The spike ran the 9.0.2 full build, which has the same encoders and filters; the CUTCAP-6 export tests pass on the essentials build with each of nvenc, amf, mf and libx264.

## Android verification (deferred to CUTCAP-9, manual)

1. Generate the fixtures above on the PC and `adb push` them to the device (`/sdcard/Movies/cutcap-fixtures/`). Add one real camera recording from the device itself (typically VFR, possibly HEVC).
2. Run the cutcap debug APK (media_kit preview). For each fixture, seek with decision 1 to frames 0, 1, last, a mid-GOP frame, and across the VFR rate change (d: 89, 90, 91), forward and backward, and step with the frame-step buttons. The burned number must equal the expected frame index. For the camera clip, compare the preview with `ffmpeg -ss {tₖ − ½f} -i clip -frames:v 1` on the PC.
3. If the preview cannot be read, capture with `adb exec-out screencap -p > shot.png`. If `hwdec` direct rendering breaks `Player.screenshot()`, use screencap instead of changing hwdec.
4. Note seek latency by eye on the camera clip (scrubbing must feel live).

**Decision rule:** if any target lands on the wrong frame and setting the mpv properties `hr-seek=yes`/`hwdec=mediacodec-copy` does not fix it, Android preview switches to ExoPlayer (`SeekParameters.EXACT`) behind `PreviewPlayer`, and must pass the same fixture check before it ships. Domain and UI do not change.

## Consequences and open risks

- Android media_kit seeking is unverified until CUTCAP-9; the `PreviewPlayer` seam keeps the fallback local.
- `media_kit_libs_windows_video` 1.0.11 bundles a libmpv from 2023-09-24, and media_kit's last release was December 2025. A security or codec issue in libmpv means waiting for upstream or forking the libs package.
- Exact seeks cost up to about 1 s on long-GOP 1080p/60 sources. Camera footage (GOP about 1 s) is far cheaper, but screen recordings may feel sluggish when scrubbing.
- When a clip's rate differs from the output rate, its first and last output frames can be one source frame off (under one output frame). This is inherent to rate conversion, and the CI duration/frame-count assertions tolerate it.
- `h264_qsv` options are untested (no Intel GPU here); a failed probe falls through safely.
- Colour is normalised to BT.709 SDR; HDR (HLG/PQ, BT.2020) sources are not tonemapped and will look washed out. The Android export tone-maps them to SDR (ADR 0004), so an HDR source exports differently on the two platforms. Non-square-pixel sources are not corrected (`setsar=1` after scale).
- Ubuntu CI runs the integration tests on a pinned static FFmpeg 9.0.2 (BtbN linux64 GPL build, `n9.0.2-39-g7adfbe40dc` from the month-end autobuild of 2026-10-31, sha256 `73e29a56974ae5a651133a04584c7483b21afe941e17dc91d79814a758b608d3`, cached by version and sha256; see `.github/workflows/ci.yml`), the same release as the Windows bundle, not the distro ffmpeg (6.x cannot tag the rotated fixture). On CI the `ffmpeg`-tagged tests fail instead of skipping when the tools are missing or cannot make a fixture. BtbN keeps month-end autobuilds; moving the pin means a new URL and its GitHub asset digest.
