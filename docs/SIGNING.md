# Signing

## Before you start

- Android: Java installed (comes with Android Studio) for the `keytool`
  command.
- iOS: an active Apple Developer Program account, Xcode installed.
- 20–30 minutes for Android; iOS signing is mostly Xcode automatically managing
  things once you're signed in, so faster.

## Android

### 1. Create the upload keystore

```
keytool -genkey -v -keystore ~/elitemeet-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for a keystore password, your name/organization details, and
a key password. **Write these down somewhere safe — if you lose this file or
its passwords, you can never publish an update to this app under the same Play
Store listing again.**

**How to know it worked:** the command creates `elitemeet-upload-keystore.jks`
in your home directory with no error.

### 2. Create android/key.properties

Copy the template and fill in the real values:

```
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

```
storePassword=<the keystore password you set above>
keyPassword=<the key password you set above>
keyAlias=upload
storeFile=/absolute/path/to/elitemeet-upload-keystore.jks
```

This file is already in `.gitignore` — confirm it's never committed:

```
git status
```

`android/key.properties` should NOT appear in the output. If it does, your
`.gitignore` isn't being picked up — check you're running this from the
project root.

**How to know it worked:** running `flutter build appbundle --release`
produces a build with no "signed with the DEBUG key" warning in the console
output (see `android/app/build.gradle` — it warns loudly if `key.properties`
is missing).

### 3. Play App Signing (recommended, Google's default now)

When you first upload to Play Console, Google offers to manage the actual
signing key for you (Play App Signing) — you upload with your local "upload
key" (created above), and Google re-signs the app with a key it manages before
distributing it to users. This is why the SHA-256 fingerprint used for
`assetlinks.json` (docs/DEEP_LINKS.md) differs between your local keystore and
what Play Console shows after your first upload — always pull that fingerprint
from **Play Console → App Integrity**, not from your local keystore.

## iOS

### 1. Confirm your Apple Developer account

App Store Connect and the Apple Developer portal need an active paid Apple
Developer Program membership (already confirmed active for this project).

### 2. Bundle ID

Already set to `net.elitemeet.app` throughout the project. In Apple Developer
portal → Identifiers, register this bundle ID if it isn't already registered
there (App Store Connect will prompt you to do this the first time you create
the app listing, if not done already).

### 3. Signing and Capabilities in Xcode

Open `ios/Runner.xcworkspace` in Xcode (after running `flutter build ios` or
`pod install` once, so the workspace exists) → select the Runner target →
Signing & Capabilities tab:

1. Check "Automatically manage signing."
2. Select your Team (your Apple Developer account).
3. Xcode will generate/download the needed certificate and provisioning
   profile automatically.

**How to know it worked:** no red error banner under Signing & Capabilities;
the "Provisioning Profile" field shows a real profile name, not "None."

### 4. Push Notifications capability

Still in Signing & Capabilities: click "+ Capability" → add "Push
Notifications." This is required in addition to the APNs key uploaded to
Firebase (docs/PUSH_NOTIFICATIONS.md) — the capability tells Apple this app is
allowed to receive push at all; the APNs key is how Firebase authenticates to
actually send it.

### 5. TestFlight / distribution signing

Once Signing & Capabilities is green, Xcode's Organizer (Window → Organizer,
after an Archive build) handles uploading to App Store Connect / TestFlight
using the same automatic signing — no separate manual certificate step needed
for most setups.

## Next step

Continue to `docs/DEEP_LINKS.md`.
