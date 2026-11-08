# cutcap

cutcap is a small offline video cutter. You add videos, split, trim, delete and reorder clips on a single track, and export the result as an ordinary mp4 with frame-accurate cuts. It deliberately stops there, so there are no effects, accounts or watermarks.

It runs on Android 10 and later and on Windows 10 22H2 / 11 (x64), from one Flutter codebase. The app is at an early stage; see [docs/SPEC.md](docs/SPEC.md) for what v1 will do.

## Installing on Windows

Each [release](https://github.com/ForeverInLaw/cutcap/releases) has a `cutcap-setup-x.y.z.exe`. It installs cutcap for your user only, without admin rights, into `%LOCALAPPDATA%\Programs\cutcap`, adds a Start menu shortcut and offers cutcap under "Open with" for mp4, mov, mkv, webm, avi and m4v files without changing their default app. FFmpeg comes bundled. The installer is unsigned, so SmartScreen asks for confirmation the first time.

You can add videos with Add video, by dropping them from Explorer onto the window, or with "Open with". Each "Open with" starts its own cutcap window, so a file opened that way while cutcap is running, or several files selected at once, do not join the edit already open; drag them onto the window instead to add them together. Windows hands over several files picked or dropped together in its own order rather than the order you clicked them in, so reorder the clips on the track if it matters.

## Installing on Android

Each release also has a `cutcap-x.y.z.apk`, signed with the same key every time, so a newer APK installs over the older one and keeps your edit. Android asks once to allow installing apps from the browser or file manager you open it with. You add videos with Add video or by sharing them to cutcap from the gallery. Exports keep running when you leave the app, with their progress and a Cancel button in a notification, and land in Movies/cutcap, where the gallery shows them straight away.

## Building

You need Flutter 3.44.8 exactly (the version is pinned in `pubspec.yaml`). Windows builds also need Visual Studio 2022 with the "Desktop development with C++" workload; Android builds need the Android SDK.

```sh
flutter pub get
flutter run -d windows
flutter build windows
flutter build apk
```

`flutter pub get` also generates the localisation code from `lib/l10n/*.arb`. A release APK is signed with the key from four environment variables described in [docs/android-release.md](docs/android-release.md); without them it falls back to the debug key. To build the installer, install [Inno Setup 6](https://jrsoftware.org/isinfo.php) and run `pwsh tool/build_installer.ps1` after `flutter build windows --release`; it writes `build/installer/cutcap-setup-x.y.z.exe`.

## License

cutcap is free software, licensed under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
