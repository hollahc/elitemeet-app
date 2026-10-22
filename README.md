# EliteMeet Mobile App

Native Android/iOS wrapper for [elitemeet.net](https://elitemeet.net), built with
Flutter. Wraps the existing website in a production WebView and adds native push
notifications, in-app billing, deep links, and camera/photo/location support —
it does **not** reimplement or redesign the website.

**New here? Start at [`docs/00_START_HERE.md`](docs/00_START_HERE.md)** — it's a
sequenced checklist through every step below, written for someone who hasn't done
this before. Unfamiliar terms are explained in [`docs/GLOSSARY.md`](docs/GLOSSARY.md).

## 1. Project overview

- Website: `https://elitemeet.net` (configurable — see `lib/config/app_config.dart`)
- Package/bundle ID: `net.elitemeet.app` (Android and iOS)
- Firebase: connected to the *existing* EliteMeet Firebase project (not a new one)

## 2. Requirements

- Flutter SDK (stable channel) — flutter.dev
- Android Studio (for the Android SDK/emulator)
- Xcode, on macOS only (for iOS — Flutter cannot build iOS from Windows/Linux)
- An active Google Play Console account and Apple Developer Program account

## 3. Flutter installation

See `docs/SETUP.md`.

## 4. Android requirements

See `docs/ANDROID_BUILD.md`.

## 5. iOS requirements

See `docs/IOS_BUILD.md`. Requires macOS + Xcode.

## 6. Firebase setup

See `docs/FIREBASE.md`.

## 7. WebView configuration

The WebView's behavior (navigation rules, back button, user agent, JS bridge)
lives in `lib/services/webview_service.dart`, `lib/services/url_router.dart`, and
`lib/services/javascript_bridge.dart`. See `docs/WEBVIEW_BRIDGE.md` for the full
contract.

## 8. Domain configuration

One place: `lib/config/app_config.dart` (`eliteMeetBaseUrl`) and
`lib/config/environment.dart` (dev/staging/production). Override at build time
with `--dart-define=ELITEMEET_BASE_URL=...` — see `docs/SETUP.md`.

## 9. Branding assets

See section "Branding" in `docs/SETUP.md` — exact filenames and source
dimensions for the logo, app icon, splash logo, and notification icon.

## 10. FCM setup

See `docs/PUSH_NOTIFICATIONS.md`.

## 11. Android billing setup

See `docs/BILLING.md`.

## 12. iOS billing setup

See `docs/BILLING.md` — same doc, both platforms.

## 13. Alternative billing configuration

See "Alternative checkout" in `docs/BILLING.md` and `docs/STORE_COMPLIANCE.md` —
availability depends on your storefront and category; nothing here is configured
to evade store policy.

## 14. Deep links

See `docs/DEEP_LINKS.md`.

## 15. Android signing

See `docs/SIGNING.md`.

## 16. iOS signing

See `docs/SIGNING.md` — same doc, both platforms.

## 17. Debug builds

```
flutter run
```

## 18. Release builds

See `docs/RELEASE.md`.

## 19. Testing

See `docs/TESTING.md`. You'll need at least one physical iPhone — push and
StoreKit sandbox purchases can't be fully tested on the Simulator.

## 20. Google Play submission

See `docs/RELEASE.md` and `docs/STORE_COMPLIANCE.md`.

## 21. App Store submission

Same docs as above — both platforms are covered together.

## 22. Troubleshooting

See `docs/TROUBLESHOOTING.md`.

---

## Project structure

```
lib/
  main.dart
  config/           # app_config.dart, environment.dart -- the domain lives here
  models/           # notification_payload.dart, purchase_product.dart
  services/         # webview_service, url_router, notification_service,
                     # purchase_service, purchase_router, deep_link_service,
                     # connectivity_service, javascript_bridge
  screens/          # webview_screen.dart
  widgets/          # app_loading.dart, error_view.dart

android/            # native Android project (applicationId: net.elitemeet.app)
ios/                # native iOS project (bundle ID: net.elitemeet.app)
docs/               # every doc referenced above
scripts/            # setup_wizard.sh / .ps1
```

## Current status

This project was built with Flutter tooling unavailable in the build
environment (network-restricted sandbox), so native Android/iOS files were
hand-written to match what `flutter create .` normally scaffolds, rather than
generated and verified directly. Run `flutter create .` in this directory first
(safe — it fills gaps without overwriting existing files), then
`flutter pub get && flutter analyze` before trusting a build. See
`docs/TROUBLESHOOTING.md` if that surfaces mismatches.
