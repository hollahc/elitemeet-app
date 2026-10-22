# Glossary

Every doc in this project links here the first time it uses one of these terms.
You don't need to read this front to back — just come back when a doc points you
here.

**Keystore** — a password-protected file that holds the cryptographic key used to
sign your Android app. Think of it as the "identity" that proves updates to your
app really come from you. Lost keystore = you can never update that app again
under the same listing.

**Provisioning profile** — an Apple file that says "this specific app, signed with
this specific certificate, is allowed to run on these specific devices (or on any
device, for App Store distribution)." Xcode usually manages this for you
automatically once you're signed into your Apple Developer account.

**Bundle ID** — Apple's name for the unique identifier of your app, e.g.
`net.elitemeet.app`. Equivalent to Android's "Application ID." Must match exactly
between App Store Connect and the app's build settings.

**Application ID** — Android's name for the same concept as Bundle ID.

**APNs (Apple Push Notification service)** — Apple's own push delivery system.
Firebase Cloud Messaging (FCM) sits on top of APNs for iOS — you still need an
APNs key uploaded to Firebase for iOS push to work at all.

**Entitlement** — in this project, "does this user currently have premium access."
Determined by the backend after verifying a purchase, not just by the app saying
"purchase succeeded."

**App Links (Android)** — lets `https://elitemeet.net/...` links open directly in
the EliteMeet app instead of a browser, once Android has verified you actually own
that domain (via `assetlinks.json`).

**Universal Links (iOS)** — the same concept as App Links, but Apple's version,
verified via `apple-app-site-association`.

**Sandbox tester (Apple)** — a special test Apple ID used only for testing
in-app purchases without being charged real money. Must be a fresh email never
used for a real Apple ID.

**License tester (Google Play)** — the Android equivalent: a Gmail address added
in Play Console that can complete test purchases without being charged.

**AAB (Android App Bundle)** — the file format Google Play requires for
submission (`app-release.aab`), as opposed to a plain installable APK.

**ProGuard / R8** — Android's code-shrinking and obfuscation tool, runs
automatically on release builds. Can silently break things that rely on
reflection (like the WebView JS bridge) unless you tell it what to keep — that's
what `proguard-rules.pro` does.

**Privacy manifest (`PrivacyInfo.xcprivacy`)** — a file Apple now requires,
declaring which "sensitive" iOS APIs your app's own code touches and why. Separate
from, and in addition to, the privacy manifests some plugins ship with themselves.

**WebView** — the native component that renders elitemeet.net inside the app. Not
a browser app — a website-rendering surface embedded in your own app's UI.

**FCM token** — a unique string Firebase generates per device/app-install that
identifies where to deliver a push notification. Changes occasionally (a
"refresh") and must be re-sent to the backend when it does.
