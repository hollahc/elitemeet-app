# iOS Privacy Manifest

## What this is

Apple now requires apps to declare, in a file called a **privacy manifest**
(`PrivacyInfo.xcprivacy`), which "required reason" APIs the app's own code
uses and why. Required-reason APIs are a specific list Apple maintains —
things like reading a file's creation timestamp, or reading UserDefaults —
that are innocuous individually but have historically been used for
fingerprinting, so Apple now requires a declared justification for each.

**This is not optional.** A missing or incomplete manifest can cause an
**automatic rejection at App Store Connect upload**, before a human reviewer
ever looks at the app — see `docs/RELEASE.md`, TestFlight processing step.

## What's already in this project

`ios/Runner/PrivacyInfo.xcprivacy` declares the app-level usage:
- NSPrivacyAccessedAPICategoryUserDefaults (reason CA92.1) — used by
  shared_preferences and the Flutter engine itself.
- NSPrivacyAccessedAPICategoryFileTimestamp (reason C617.1) — common across
  several plugins' native code.

It also declares the data types collected (device ID for the FCM token,
precise location) — kept in sync with `docs/PRIVACY_DECLARATIONS.md`.

## Important: this file doesn't cover plugins' own usage

Many Flutter plugins (Firebase packages, some WebView/billing packages) ship
their **own** PrivacyInfo.xcprivacy inside their CocoaPods pod. The app-level
file above only covers what the app's own Dart/Swift code does — it does not
replace what each plugin declares for itself.

## Before every iOS submission

A plugin version bump can silently add a new required-reason API without any
code change on your part. Before submitting:

1. Run `flutter pub outdated` and note if any Firebase, webview, or billing
   plugin was recently updated.
2. Check that plugin's own privacy manifest (usually visible in its pub.dev
   page or its source repo under `ios/*/PrivacyInfo.xcprivacy`) for anything
   new.
3. If App Store Connect rejects the upload citing a missing privacy manifest
   reason, the rejection message names the specific API category — add the
   matching declaration to `ios/Runner/PrivacyInfo.xcprivacy` if it's genuinely
   the app's own usage, or confirm the offending plugin has updated its own
   manifest if it's plugin-level.

## How to know it's correct

- Archive the app in Xcode (Product → Archive) — Xcode itself will flag
  obviously missing required-reason declarations before you even get to
  upload.
- A successful TestFlight upload with no privacy-manifest rejection email
  from App Store Connect is the practical confirmation.

## Next step

Continue to `docs/WEBSITE_INTEGRATION.md`.
