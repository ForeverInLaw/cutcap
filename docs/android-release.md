# Android release signing

Every release APK is signed with one persistent key, so a new version installs over the previous one. The key never enters the repository: the owner creates it once and stores it in four GitHub Actions secrets, and the `android` job in `.github/workflows/ci.yml` uses them only on `v*` tags. It fails with the names of the missing secrets when any is unset, and refuses an APK signed with a debug key.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password |
| `ANDROID_KEY_ALIAS` | The key's alias in the keystore |
| `ANDROID_KEY_PASSWORD` | The key's password (for a PKCS12 keystore the same as the keystore password) |

CI decodes the keystore into a temporary file and passes its path to Gradle as `ANDROID_KEYSTORE_PATH`, with the other three secrets as environment variables of the same names (`android/app/build.gradle.kts`). A local release build with the same four variables set produces the same signature; without them, Gradle falls back to the debug key, so `flutter run --release` keeps working.

## Creating the key (once)

With the JDK's `keytool` (PowerShell, outside the repository):

```powershell
keytool -genkeypair -v -keystore cutcap-release.jks -storetype PKCS12 `
  -alias cutcap -keyalg RSA -keysize 4096 -validity 10000 `
  -dname "CN=cutcap, O=ForeverInLaw"
```

keytool asks for one password; PKCS12 uses it for the key as well. Keep the `.jks` file and the password in a password manager or another safe backup. Losing either means no later APK can update an installed cutcap; users would have to uninstall first, losing the autosaved edit.

## Setting the secrets

From the directory holding the keystore, with the GitHub CLI logged in:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\cutcap-release.jks")) |
  gh secret set ANDROID_KEYSTORE_BASE64 --repo ForeverInLaw/cutcap
gh secret set ANDROID_KEY_ALIAS --repo ForeverInLaw/cutcap --body cutcap
gh secret set ANDROID_KEYSTORE_PASSWORD --repo ForeverInLaw/cutcap
gh secret set ANDROID_KEY_PASSWORD --repo ForeverInLaw/cutcap
```

The last two prompt for the value, so the password stays out of the shell history. Enter the keystore password both times. `gh secret list --repo ForeverInLaw/cutcap` should then list all four.

## Publishing a release

1. Raise `version` in `pubspec.yaml`, both the name and the build number after `+`. Android installs an update only when the build number (`versionCode`) is higher than the installed one.
2. Push a tag `vX.Y.Z` equal to that version name. The `release` job attaches `cutcap-X.Y.Z.apk` and `cutcap-setup-X.Y.Z.exe` to one GitHub Release.

The release APK is signed with a different key than the CI debug APKs, so a phone with a debug build has to uninstall it before installing the release (Android refuses an update signed by another key).
