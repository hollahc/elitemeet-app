# Android Build

## Before you start

- `docs/SETUP.md` completed (`flutter create .`, `flutter pub get` done).
- For a release build: `docs/SIGNING.md` completed.
- 5–15 minutes depending on build type.

## Debug build (for local testing)

```
flutter run
```

Installs and launches on a connected device or running emulator. Hot-reload
works normally for anything in `lib/` — WebView content itself reloads by
pulling from elitemeet.net each time, not from local files.

## Debug APK (to share with someone for testing, no signing needed)

```
flutter build apk --debug
```

**Output:** `build/app/outputs/flutter-apk/app-debug.apk`

## Release AAB (the file Google Play requires for submission)

```
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

This is the artifact you upload to Google Play Console.

**How to know it worked:** the command ends with "Built
build/app/outputs/bundle/release/app-release.aab" and no red error text.
Check the console output above that line for the signing warning mentioned in
`docs/SIGNING.md` — if you see "signed with the DEBUG key," this build is not
suitable for Play Store upload.

## Release APK (for direct install/testing, not for Play Store)

```
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

## Critical: always smoke-test a release build before uploading

Release builds have code shrinking (ProGuard/R8) enabled
(`android/app/build.gradle`, `minifyEnabled true`). This can silently break the
WebView JS bridge, Firebase Messaging, or billing plugins even when the build
itself "succeeds" — `proguard-rules.pro` has keep-rules for the plugins used
here, but a version bump or a new plugin can introduce a gap.

**Before every upload:**
1. Install the release APK on a real device:
   ```
   flutter install --release
   ```
2. Log in through the WebView.
3. Trigger a push notification (docs/PUSH_NOTIFICATIONS.md, "Testing").
4. Run through a sandbox purchase (docs/BILLING.md).

If any of these fail in the release build but worked in debug, it's almost
always a ProGuard stripping issue — check `android/app/proguard-rules.pro` for
a missing keep-rule for whatever plugin is involved.

## Useful housekeeping commands

```
flutter clean
flutter pub get
```

Run this pair if you hit stale-build errors after changing native config
(Gradle files, manifest) — Flutter doesn't always pick up native changes
without a clean.

## Next step

Continue to `docs/IOS_BUILD.md`, then `docs/TESTING.md`.
