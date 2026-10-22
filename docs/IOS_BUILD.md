# iOS Build

## Before you start

- **macOS with Xcode installed is required.** Flutter's iOS build tooling only
  works on macOS — there is no way to build for iOS from Windows or Linux, even
  though everything else in this project can be edited on any OS.
- `docs/SETUP.md` and `docs/SIGNING.md` (iOS section) completed.
- 15–30 minutes.

## Install CocoaPods dependencies (first time, or after adding a plugin)

```
cd ios
pod install
cd ..
```

**How to know it worked:** ends with "Pod installation complete!" and
`ios/Runner.xcworkspace` exists (note: `.xcworkspace`, not `.xcodeproj` — always
open the workspace from here on, not the project file directly).

## Debug build (Simulator or a connected device)

```
flutter run
```

**Note:** push notifications and StoreKit sandbox purchases do not work on the
Simulator — use a physical device for testing those (docs/TESTING.md).

## Release build

```
flutter build ipa --release
```

**Output:** an `.xcarchive` and `.ipa` under `build/ios/`.

**How to know it worked:** ends with "Built IPA to build/ios/ipa" with no red
error text.

**If it didn't work:** the vast majority of iOS build failures are signing
issues — re-check `docs/SIGNING.md`, specifically that Signing & Capabilities
in Xcode shows a real Team and provisioning profile, not "None."

## Uploading to TestFlight

`flutter build ipa` produces the file, but the actual upload to App Store
Connect is done through Xcode's Organizer, not a Flutter command:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Product menu → Archive (this re-archives; you can also use the `.xcarchive`
   already produced above by opening it in Organizer directly).
3. Once archiving finishes, the Organizer window opens automatically → select
   the archive → "Distribute App" → "App Store Connect" → follow the prompts
   (uses the automatic signing already configured).

**How to know it worked:** Organizer shows "Upload Successful." The build then
appears in App Store Connect → TestFlight within a few minutes to an hour
(Apple's processing time varies).

**If it didn't work:** "No suitable application records were found" usually
means the bundle ID (`net.elitemeet.app`) hasn't been registered as an App ID
in App Store Connect yet — create the app listing there first (My Apps → "+"
→ New App), then retry the upload.

## Next step

Continue to `docs/TESTING.md`.
