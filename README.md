# cutcap

cutcap is a small offline video cutter. You add videos, split, trim, delete and reorder clips on a single track, and export the result as an ordinary mp4 with frame-accurate cuts. It deliberately stops there, so there are no effects, accounts or watermarks.

It runs on Android 10 and later and on Windows 10 22H2 / 11 (x64), from one Flutter codebase. The app is at an early stage; see [docs/SPEC.md](docs/SPEC.md) for what v1 will do.

## Building

You need Flutter 3.44.8 exactly (the version is pinned in `pubspec.yaml`). Windows builds also need Visual Studio 2022 with the "Desktop development with C++" workload; Android builds need the Android SDK.

```sh
flutter pub get
flutter run -d windows
flutter build windows
flutter build apk
```

`flutter pub get` also generates the localisation code from `lib/l10n/*.arb`.

## License

cutcap is free software, licensed under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
