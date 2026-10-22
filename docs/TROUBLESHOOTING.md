# Troubleshooting

Organized by the phase in `docs/00_START_HERE.md` where each issue tends to show
up.

## Setup / first build

**"flutter.sdk not set in local.properties"**
`flutter create .` wasn't run yet, or was run in the wrong directory. Run it
from the project root (where pubspec.yaml lives).

**flutter analyze reports errors immediately after cloning**
Run `flutter pub get` first — most "undefined class" errors are just missing
packages, not real code problems.

**App builds but shows a blank white screen at launch**
The native splash (launch_background.xml) hasn't been generated from real
assets yet — see `docs/SETUP.md`, Branding section, and run
`dart run flutter_native_splash:create`.

## Firebase

**"No Firebase projects found" during flutterfire configure**
You're logged into the wrong Google account — it needs access to the existing
EliteMeet Firebase project. See `docs/FIREBASE.md`.

**App crashes on launch after adding Firebase**
Almost always a missing google-services.json (Android) or
GoogleService-Info.plist (iOS) in the wrong location — Android needs it at
android/app/google-services.json specifically, not the project root.

## Push notifications

**Notifications never arrive on Android**
Check POST_NOTIFICATIONS was actually granted (device Settings → Apps →
EliteMeet → Notifications) — it's a runtime permission on Android 13+, not
automatic.

**Notifications never arrive on iOS**
Confirm you're testing on a physical device (Simulator can't receive real
push), and that the APNs key step in `docs/PUSH_NOTIFICATIONS.md` was
completed.

**Notification tap opens the wrong page or doesn't navigate**
Check the FCM payload actually includes data.url — see
`docs/WEBSITE_INTEGRATION.md`, section 7. A payload with only a notification
block and no data.url will show the notification but has nothing to navigate
to.

## Billing

**"Product not found" or similarly generic error on purchase**
Almost always a product ID mismatch — check the ID in
lib/models/purchase_product.dart matches the console exactly, including case.
See `docs/BILLING.md`.

**Purchase succeeds in the store sheet but the account isn't upgraded**
The server couldn't verify it. Check the web server logs for
`[store-billing]` — usually the Google Play service account / App Store API
key isn't set in Admin → API Keys, or the service account hasn't been granted
access in Play Console. The purchase stays unfinished and is retried on the
next page load; Google auto-refunds it after 3 days if never verified. See
`docs/BILLING.md`, "Server credentials."

**Real money charged during testing**
The test account wasn't added as a Play Console license tester or an App
Store Connect sandbox tester before testing — see `docs/BILLING.md`.

## Deep links

**Link opens the browser instead of the app**
Run `adb shell pm get-app-links net.elitemeet.app` (Android) and check for
"verified" — if not, recheck assetlinks.json is hosted correctly (right
Content-Type, right fingerprint from Play Console, not your local keystore —
see `docs/DEEP_LINKS.md`). On iOS, confirm Associated Domains is added in
Xcode and you're testing on a fresh install.

## Android release build

**Something works in debug but breaks in release**
Almost always ProGuard/R8 stripping a class it doesn't know it needs to keep —
check android/app/proguard-rules.pro for the plugin involved. See
`docs/ANDROID_BUILD.md`.

**"signed with the DEBUG key" warning**
android/key.properties doesn't exist yet or has a wrong path/password — see
`docs/SIGNING.md`.

## iOS build

**Signing errors ("No signing certificate," "No profile found")**
Re-check Xcode → Runner target → Signing & Capabilities — automatic signing
needs a Team selected. See `docs/SIGNING.md`.

**Build works but iOS build tools say to run on macOS**
There's no way around this — Flutter's iOS toolchain requires macOS + Xcode.
See `docs/IOS_BUILD.md`.

## Store submission

**Automatic rejection at TestFlight upload citing a privacy manifest**
See `docs/IOS_PRIVACY_MANIFEST.md` — a plugin update likely added a new
required-reason API that needs declaring.

**Rejected for missing Restore Purchases**
See `docs/BILLING.md`, "Restore Purchases" — must be reachable and tested via
reinstall, not just present as backend logic.

**Rejected for a generic permission string**
Re-check the actual copy in Info.plist / AndroidManifest.xml against what
Apple/Google flagged — see `docs/SETUP.md` and `docs/STORE_COMPLIANCE.md`.

## Still stuck?

Cross-check the specific phase against `docs/00_START_HERE.md` to confirm
nothing earlier in the sequence was skipped — most build-time errors trace
back to a console step (Firebase, signing, product creation) that hadn't been
done yet rather than a code problem.
