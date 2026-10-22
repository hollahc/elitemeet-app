# Push Notifications (FCM)

## Before you start

- `docs/FIREBASE.md` completed (google-services.json / GoogleService-Info.plist
  exist).
- An Apple Developer account (for the APNs key — iOS only).
- 15–20 minutes.

## 1. Upload an APNs key to Firebase (iOS only, one-time per project)

Skip this if someone has already done it for the existing EliteMeet Firebase
project.

1. Apple Developer account → Certificates, Identifiers & Profiles → Keys → the
   `+` button → check "Apple Push Notifications service (APNs)" → Continue →
   Register. Download the `.p8` key file **immediately** — Apple only lets you
   download it once.
2. Note the **Key ID** shown on the key's page, and your **Team ID** (top right
   of the Apple Developer account page).
3. Firebase console → EliteMeet project → Project settings → Cloud Messaging →
   Apple app configuration → APNs Authentication Key → Upload → select the
   `.p8` file, enter the Key ID and Team ID.

**How to know it worked:** the Cloud Messaging settings page shows the key as
uploaded with no error banner.

## 2. Where permission is requested (already wired in code)

`NotificationService.requestPermission()` in
`lib/services/notification_service.dart` handles both platforms, but it's
**not called automatically on app launch** — per Section 62, asking for
notification permission on cold start (before the person has any context for
why) hurts opt-in rates and can read as spammy in review. Call it from wherever
your login/onboarding flow makes sense to trigger — typically right after the
person logs in. The website can also trigger it via the JS bridge:
`window.EliteMeetApp.requestNotificationPermission()` — see
`docs/WEBVIEW_BRIDGE.md`.

## 3. What happens on tap (already wired in code)

`lib/screens/webview_screen.dart` listens to
`NotificationService.instance.pendingDeepLink` and navigates the WebView to
whatever URL arrives in the FCM payload's `data.url` field — covering
foreground, background, and terminated-launch cases. The backend needs to send
that field — see `docs/WEBSITE_INTEGRATION.md` for the exact payload shape.

## 4. Testing

**How to know it worked (Android):**
1. Run the app on a device or emulator with Google Play services.
2. From Firebase console → Cloud Messaging → "Send test message", paste in the
   FCM token (get it by calling `window.EliteMeetApp.getDeviceToken()` from the
   WebView's JS console, or temporarily logging it in
   `NotificationService.getToken()`).
3. A notification should appear within a few seconds.

**How to know it worked (iOS):** same Firebase console flow, but **must be run
on a physical iPhone** — the Simulator cannot receive real push notifications.

**If it didn't work:**
- Android, nothing arrives: confirm `google-services.json` is in
  `android/app/` (not just the project root), and that
  `POST_NOTIFICATIONS` permission was actually granted (check device Settings →
  Apps → EliteMeet → Notifications).
- iOS, nothing arrives: confirm the APNs key step above was completed, and that
  you're testing on a real device signed into a real Apple ID with notifications
  enabled for the app.
- Token is `null` when calling `getToken()`: Firebase likely failed to
  initialize — check `flutter run` console output for
  `[NotificationService] Firebase init failed`.

## Next step

Continue to `docs/BILLING.md`.
