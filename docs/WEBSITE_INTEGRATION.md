# Website Integration — What elitemeet.net Needs to Implement

This is for whoever works on the elitemeet.net codebase (may be you, may be a
separate frontend/backend team). It explains what the website needs to add to
work with the mobile app. Full API reference: `docs/WEBVIEW_BRIDGE.md`
("EliteMeetApp API v1").

## 1. Detecting the app

```javascript
const isEliteMeetApp = Boolean(window.EliteMeetApp);
const platform = window.EliteMeetApp?.platform; // "android" | "ios" | undefined
```

Use this to hide "Download our app" banners when already inside it, or adjust
UI chrome (e.g. hide a redundant top nav bar the native app's status bar
already separates).

## 2. Receiving and registering the FCM token

```javascript
// Pull the current token any time (e.g. right after login):
async function registerDeviceToken() {
  if (!window.EliteMeetApp) return; // not in the app - nothing to do
  const token = await window.EliteMeetApp.getDeviceToken();
  if (token) {
    await fetch('/api/mobile/register-device', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, platform: window.EliteMeetApp.platform }),
      credentials: 'include', // send the existing session cookie
    });
  }
}

// Also listen for refreshes - don't rely on the pull above alone:
window.addEventListener('elitemeetTokenUpdate', async (e) => {
  const token = e.detail.token;
  if (token) {
    await fetch('/api/mobile/register-device', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, platform: window.EliteMeetApp?.platform }),
      credentials: 'include',
    });
  }
});
```

`/api/mobile/register-device` is a placeholder endpoint name — replace with
whatever the actual EliteMeet backend route is (or create it if it doesn't
exist yet).

## 3. Requesting notification permission

Call this from wherever makes sense in your flow (e.g. right after login, or
from a settings toggle) — not automatically on every page load:

```javascript
async function askForNotifications() {
  if (!window.EliteMeetApp) return;
  const granted = await window.EliteMeetApp.requestNotificationPermission();
  if (granted) registerDeviceToken();
}
```

## 4. Logout / token cleanup

When the user logs out, tell your backend to stop sending push to this
token/user pairing (multiple devices per user should be supported — don't
delete other devices' tokens, just this session's):

```javascript
async function onLogout() {
  if (window.EliteMeetApp) {
    const token = await window.EliteMeetApp.getDeviceToken();
    await fetch('/api/mobile/unregister-device', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
      credentials: 'include',
    });
  }
  // ... rest of your normal logout flow
}
```

## 5. Initiating a purchase

Already implemented in the EliteMeet web app — `src/lib/native-billing.ts`
(`buyInApp`) and `src/components/NativeBillingBridge.tsx`. Every purchase
surface (plans, boosts/rewinds/super likes, message bundles, verification
fee) switches to store billing automatically when `window.EliteMeetApp`
exposes `finishPurchase`.

```javascript
window.EliteMeetApp.purchase({
  productId: 'elitemeet_gold_monthly',
  accountId: currentUser.id,   // binds the receipt to this EliteMeet account
  subscription: true,
});
```

Product IDs: see `docs/BILLING.md`.

## 6. Receiving the purchase result

The app never grants anything. It hands the receipt to the page, the page
sends it to the server (`verifyStorePurchase`), and the page tells the app
to finish the store transaction:

```javascript
window.addEventListener('elitemeetPurchaseVerify', async (e) => {
  const p = e.detail; // { key, platform, productId, purchaseToken, transactionId, restored }
  const r = await verifyStorePurchase(p);          // server checks with Google/Apple
  if (r.status === 'granted')  await window.EliteMeetApp.finishPurchase({ key: p.key, ok: true });
  if (r.status === 'rejected') await window.EliteMeetApp.finishPurchase({ key: p.key, ok: false });
  // 'pending' / 'retry': leave it — the app re-offers it via getPendingPurchases()
});

// Cancelled / pending / error from the store sheet itself:
window.addEventListener('elitemeetPurchaseComplete', (e) => {
  const { productId, status, errorMessage } = e.detail; // 'cancelled' | 'pending' | 'error'
});
```

On every page load, call `window.EliteMeetApp.getPendingPurchases()` too —
purchases that completed while no page was listening wait there.

## 7. Handling deep-link navigation

No website code needed for this — the app navigates the WebView directly to
the internal URL. What the **backend** needs to send: FCM payloads that
include a `data.url` field pointing at the internal path to open, e.g.:

```json
{
  "notification": { "title": "New message", "body": "..." },
  "data": { "url": "/messages/123" }
}
```

Relative paths are resolved against the configured base URL automatically by
the app.

## 8. Account deletion (Google Play requirement)

No new work needed if the existing delete-account page is reachable from
within the WebView (e.g. from an account/settings page a logged-in user can
navigate to normally) — see `docs/STORE_COMPLIANCE.md`.

## API contract versioning

This is "EliteMeetApp API v1." If the native app ever ships a breaking change
to this contract, `window.EliteMeetApp.__version` increments — website code
can check it if you need to branch behavior for users on an older app version
who haven't updated yet.

## Next step

Continue to `docs/TROUBLESHOOTING.md` if you hit issues, or back to
`docs/00_START_HERE.md` for the full sequence.
