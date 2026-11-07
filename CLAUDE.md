# cutcap

Minimal frame-accurate video cutter for Android 10+ and Windows 10/11 x64, built with Flutter. GPL-3.0-or-later.

- Product spec: `docs/SPEC.md`
- Decisions: `docs/adr/`
- UI design work goes through the `impeccable` skill.

## Commands

Flutter 3.44.8 exactly (pinned in `pubspec.yaml` under `environment.flutter`; CI reads it from there). Targets: `windows`, `android` only.

| Task | Command |
| --- | --- |
| Fetch deps (also runs gen-l10n) | `flutter pub get` |
| Regenerate l10n after editing `lib/l10n/*.arb` | `flutter gen-l10n` |
| Format check (CI) | `dart format --output=none --set-exit-if-changed .` |
| Analyze (CI) | `flutter analyze` |
| Test one file | `flutter test test/app_test.dart` |
| Test all (CI) | `flutter test` |
| Export integration tests only (need ffmpeg + ffprobe on PATH, skipped otherwise) | `flutter test --tags ffmpeg` |
| Fetch the pinned Windows FFmpeg (sha256-verified) | `pwsh tool/fetch_ffmpeg.ps1 -Destination <dir>` |
| Run on Windows | `flutter run -d windows` |
| Build Windows | `flutter build windows` (`--debug` for a quick check) |
| Build Android APK | `flutter build apk` (needs the Android SDK, which the dev box does not have) |

Generated `lib/l10n/app_localizations*.dart` files are gitignored; the `.arb` files are the source of truth. CI is `.github/workflows/ci.yml`.

## Agent skills

### Issue tracker

Issues live in the itsaplan project CUTCAP (`redstone.CUTCAP`), driven via the `mcp__itsaplan__*` tools. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the root (created lazily) and `docs/adr/`. See `docs/agents/domain.md`.
