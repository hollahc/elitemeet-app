# Testing

## Before you start

- **You will need at least one physical iPhone before you can confirm push
  notifications and purchases work.** Push and StoreKit sandbox purchases
  cannot be fully tested on the iOS Simulator — this is a hardware
  requirement, not a configuration gap, so it's worth knowing before you get
  to that point rather than discovering it at the end.
- Android testing can be done on an emulator for most things, but a physical
  device is still recommended for push/purchase testing for the same reason
  (emulators without Google Play services installed can't test either).

## Android

| Area | How to test |
|---|---|
| Emulator | Android Studio, Device Manager, run an emulator with a Google Play (not Google APIs) system image — needed for billing to work at all |
| Physical device | Enable Developer Options + USB debugging, `flutter run` |
| Android 13+ | Confirm the `POST_NOTIFICATIONS` prompt appears when `requestNotificationPermission()` is called, not on cold start |
| Push notification | docs/PUSH_NOTIFICATIONS.md, "Testing" section |
| Purchase | docs/BILLING.md — use a license tester account |
| WebView | Navigate the site normally; confirm JS console has no errors (Chrome remote debugging — see docs/WEBVIEW_BRIDGE.md) |
| Back button | From a few levels deep in site navigation, press system back — should navigate WebView history, not close the app, until history is exhausted |
| File upload | Trigger any photo-upload flow on the site; confirm the Android Photo Picker opens (not a permission dialog) |
| Camera | Trigger a camera-capture flow if the site has one; confirm the permission prompt appears only at that point |
| Deep link | docs/DEEP_LINKS.md, "Verify" section |

## iOS

| Area | How to test |
|---|---|
| Physical iPhone | Required for push and purchases — see above |
| Push notification | docs/PUSH_NOTIFICATIONS.md, "Testing" section |
| TestFlight | docs/IOS_BUILD.md, "Uploading to TestFlight" |
| Sandbox purchase | docs/BILLING.md — sign into the sandbox tester Apple ID on-device first |
| WebView | Navigate the site normally; use Safari's Develop menu against a debug build to inspect |
| Universal Links | docs/DEEP_LINKS.md, "Verify" section |
| File upload | Trigger a photo-upload flow; confirm the photo library/camera picker appears with the correct permission prompt text |
| Camera | Trigger a camera-capture flow; confirm NSCameraUsageDescription text (Info.plist) shows correctly in the system prompt |
| Photo library | Same, for NSPhotoLibraryUsageDescription |

## Cross-platform

- [ ] Deny the location permission once (site's nearby-matches feature) and
      confirm the site degrades gracefully rather than hanging — Section 70.
- [ ] Kill the app fully, tap a push notification — confirms the terminated-
      state notification-tap path (docs/PUSH_NOTIFICATIONS.md).
- [ ] Turn off Wi-Fi/data mid-session — confirm the offline screen appears and
      auto-retries once connectivity returns (connectivity_service.dart).
- [ ] Release-build smoke test on Android — see docs/ANDROID_BUILD.md,
      "Critical: always smoke-test a release build."

## Automated tests

Run:
```
flutter test
```

Covers URL routing, purchase routing, environment configuration, notification
payload parsing, and configuration validation — see `test/` for what's
included. This is not a substitute for the manual device testing above,
particularly for push/purchase flows that automated tests can't exercise.

## Next step

Continue to `docs/RELEASE.md`.
