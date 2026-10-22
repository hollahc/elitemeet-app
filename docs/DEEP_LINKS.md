# Deep Links (App Links / Universal Links)

## Before you start

- `docs/SIGNING.md` completed for Android (you need the Play Console
  fingerprint, which only exists after a first upload).
- Access to host static files on elitemeet.net (ask whoever manages the
  website's hosting/deployment if that isn't you).
- 15–20 minutes, plus waiting time for the first Play Console upload before
  Android verification can be finalized.

## What this enables

Tapping an `https://elitemeet.net/...` link anywhere outside the app (another
app, a text message, search results) opens this app directly instead of a
browser, if the app is installed. Already implemented in Dart:
`lib/services/deep_link_service.dart`.

## Android — App Links

### 1. Get the SHA-256 signing fingerprint

**Important sequencing note:** the fingerprint needed here is different for a
debug build, a locally-signed release build, and Google Play App Signing (Play
re-signs the app after upload — see docs/SIGNING.md). The one that matters for
a **production** app is the one Play Console shows, not your local keystore.

1. Upload the app to Play Console at least once (even to Internal Testing).
2. Play Console → your app → Setup → App Integrity → App signing key
   certificate → copy the **SHA-256 certificate fingerprint**.

(For local testing before your first upload, you can temporarily use the
fingerprint from your own keystore — `keytool -list -v -keystore
~/elitemeet-upload-keystore.jks` — but replace it with the Play Console value
before relying on this in production.)

### 2. Host assetlinks.json

Create this file and host it at exactly:
`https://elitemeet.net/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "net.elitemeet.app",
    "sha256_cert_fingerprints": ["<the fingerprint from step 1>"]
  }
}]
```

**How to know it worked:**
```
curl https://elitemeet.net/.well-known/assetlinks.json
```
should return this JSON with a `200` status and `Content-Type:
application/json`. Also run Google's Statement List Generator/verification
tool (search "Digital Asset Links API validator") and paste the URL to confirm
Android can parse it.

**If it didn't work:** most common issue is the file being served with the
wrong Content-Type (some static hosts serve `.json` as `text/plain` by
default) — Android's verifier is strict about this.

### 3. AndroidManifest.xml

Already configured in `android/app/src/main/AndroidManifest.xml` with
`android:autoVerify="true"` on the `elitemeet.net` intent filter — no
additional Android code changes needed once `assetlinks.json` is live.

### 4. Verify

Install the app on a device, then run:
```
adb shell pm get-app-links net.elitemeet.app
```
Look for `elitemeet.net: verified` in the output. If it says something else
(e.g. `legacy_failure`), the `assetlinks.json` file/fingerprint don't match —
recheck steps 1–2.

## iOS — Universal Links

### 1. Host apple-app-site-association

Host at exactly: `https://elitemeet.net/.well-known/apple-app-site-association`
(no `.json` extension, served with `Content-Type: application/json`, no
redirects — Apple's fetcher won't follow them).

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.net.elitemeet.app",
        "paths": ["*"]
      }
    ]
  }
}
```

Replace `<TEAM_ID>` with your Apple Developer Team ID (Apple Developer account
→ Membership details).

**How to know it worked:**
```
curl -I https://elitemeet.net/.well-known/apple-app-site-association
```
should return `200` with `Content-Type: application/json`.

### 2. Xcode — Associated Domains capability

Runner target → Signing & Capabilities → "+ Capability" → Associated Domains
→ add:
```
applinks:elitemeet.net
```

### 3. Verify

Install the app on a physical iPhone, then send yourself a text message
containing an `https://elitemeet.net/...` link and tap it — it should open
directly in the app, not Safari. If it opens Safari instead, the most common
causes are: the JSON not being reachable (recheck the curl test above), a
redirect on that URL (Apple's fetcher doesn't follow them), or the Associated
Domains capability not actually being applied (re-check Signing &
Capabilities in Xcode, and that you're testing a fresh install — iOS caches
the AASA file per install).

## Next step

Continue to `docs/ANDROID_BUILD.md` and `docs/IOS_BUILD.md`.
