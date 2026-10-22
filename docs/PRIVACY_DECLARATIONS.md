# Privacy Declarations (Data Safety / App Privacy)

Both stores require a console form declaring what data your app actually
collects. **The form must match real behavior exactly** — this is one of the
more common causes of rejection or later removal, so fill it from this table
rather than guessing.

## What this app actually collects, and where it maps in each console

| Data type | Where it comes from in this app | Google Play Data Safety field | Apple App Privacy field |
|---|---|---|---|
| FCM/device token | NotificationService.getToken() — used to deliver push | Device or other IDs | Device ID |
| Device/app info (platform, version) | getPlatform(), getAppVersion() in the JS bridge | App info and performance (Diagnostics), or App activity depending on how it's used server-side | App Functionality |
| Precise location | Section 70 geolocation bridge, if/when the website's WebChromeClient prompt is granted | Location - Approximate or Precise location | Precise Location |
| Purchase history | Handled via Play Billing / StoreKit — the app itself doesn't store this beyond what's needed for the purchase flow | Financial info - Purchase history (Google collects/manages most of this on its own for Play Billing purchases — confirm current guidance in Play Console when filling the form) | Purchase History |
| Account/login data | Handled entirely by elitemeet.net via cookies in the WebView — the app itself does not directly collect login credentials | Depends on what the website's own privacy policy already discloses — this app doesn't add new collection beyond what the website already does in a browser | Same — cross-reference the website's existing privacy policy |
| Uploaded photos | File uploads go through the website's own upload flow inside the WebView; the app's role is limited to the native file/camera picker | Photos and videos, if the website's own data safety disclosure doesn't already cover this | Photos or Videos |

## Before filling in the actual console forms

1. Check what the website's existing privacy policy already discloses for
   account data, uploaded photos, and purchase history — those forms should
   stay consistent with what elitemeet.net (the browser version) already
   tells users, not introduce new collection the app alone is doing.
2. Cross-reference `ios/Runner/PrivacyInfo.xcprivacy` — the data types
   declared there (device ID, precise location) should match what you select
   in Apple's App Privacy form. See `docs/IOS_PRIVACY_MANIFEST.md`.
3. If geolocation ends up NOT being used in the shipped build for some reason,
   remove the location declaration from both PrivacyInfo.xcprivacy and the
   console forms — declaring collection that doesn't actually happen is just
   as much a mismatch as the reverse.

## Where to fill each form

- **Google Play:** Play Console → your app → Policy → App content → Data
  safety.
- **Apple:** App Store Connect → your app → App Privacy.

Neither form is optional before submission on either platform.

## Next step

Continue to `docs/IOS_PRIVACY_MANIFEST.md`.
