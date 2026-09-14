# iOS builds

The Flutter project is `flutter_app`; the repository root also contains a separate
Android project. Select a workflow from the root `codemagic.yaml`.

## Reproducible toolchain

- Flutter 3.41.2 (the locally installed SDK used for dependency resolution).
- Xcode 16.2 and CocoaPods 1.16.2 on Codemagic.
- iOS 15.0 deployment target.
- Commit `pubspec.lock`; CI uses `flutter pub get --enforce-lockfile`.
- CocoaPods integration is intentional for these plugin versions. Do not switch
  the Flutter version or upgrade Firebase plugins independently of native checks.

## Checks before Xcode compilation

Run from `flutter_app`:

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
python3 -B -m unittest discover -s tool -p 'test_*.py'
python3 tool/check_ios_configuration.py
python3 tool/patch_firebase_ios.py
```

Analysis errors and warnings fail CI. Style/deprecation notices remain visible
but do not block compilation. The Firebase patch is tested for fresh downloads,
already patched sources, and repeat execution. The Podfile also removes the
invalid BoringSSL-GRPC compiler flag on every `pod install`.

On macOS, install pods and compile the unsigned app:

```sh
cd ios
pod install --repo-update
cd ..
flutter build ios --release --no-codesign
```

Open `ios/Runner.xcworkspace` in Xcode, not the workspace under `RunnerTests`.
An unsigned `.app` verifies compilation; installation on a physical iPhone
requires signing. Codemagic retains `Podfile.lock` with the build artifacts so
the resolved native dependency versions can be reviewed after a build.

## Signed workflow configuration still required

The checked-in Firebase iOS app and Runner use `com.kina.goldenHandCare`.
The existing TestFlight workflow requests signing for `com.kina.care` and changes
Runner to that identifier. These are distinct application registrations.

Before running the signed workflow, select the intended identifier:

- If retaining `com.kina.goldenHandCare`, use matching App Store Connect and
  provisioning registrations and update the signing workflow accordingly.
- If retaining `com.kina.care`, supply its registered `GoogleService-Info.plist`
  and matching Google Sign-In client ID and callback URL scheme. Editing only
  the `BUNDLE_ID` in the old Firebase plist does not register the new app.

The configuration check runs again after the signed workflow changes Runner's
identifier, so this mismatch is reported before a long native compilation.
The unsigned workflow uses the existing matching Firebase registration.

Only a successful macOS/Xcode build confirms native compilation. Windows source
analysis and Python checks cannot verify CocoaPods linking or Apple signing.
