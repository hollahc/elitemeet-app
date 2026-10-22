# WebView Bridge — window.EliteMeetApp API v1

This is the contract between the Flutter app and elitemeet.net. The website
calls these methods; the app implements them natively. Implementation:
`lib/services/javascript_bridge.dart`.

## Detecting the app

```javascript
const isEliteMeetApp = Boolean(window.EliteMeetApp);
```

`window.EliteMeetApp` only exists inside the native app's WebView — never on a
desktop or mobile browser. Use this to conditionally show app-specific UI (e.g.
hide "Download our app" banners when already inside it).

## Methods

All methods are async (return a Promise).

### getPlatform()

```javascript
const platform = await window.EliteMeetApp.getPlatform();
// "android" | "ios"
```

Also available synchronously as `window.EliteMeetApp.platform` (set at bridge
install time, no round-trip needed).

### getAppVersion()

```javascript
const version = await window.EliteMeetApp.getAppVersion();
// "1.0.0"
```

### getDeviceToken()

```javascript
const token = await window.EliteMeetApp.getDeviceToken();
// FCM token string, or null if unavailable
```

Register this against the logged-in user server-side. Don't rely on this call
alone for refreshes — also listen for the push event below, which fires
automatically when the token changes.

### requestNotificationPermission()

```javascript
const granted = await window.EliteMeetApp.requestNotificationPermission();
// true | false
```

Call this from a moment that makes sense in your UI flow (e.g. right after
login), not automatically on page load — see docs/PUSH_NOTIFICATIONS.md for why.

### purchase({ productId, accountId, subscription })

```javascript
window.EliteMeetApp.purchase({ productId: "elitemeet_gold_monthly", accountId: user.id, subscription: true });
```

Opens the native store sheet. `accountId` (the EliteMeet user id, a UUID)
is attached to the transaction so the server can reject a receipt replayed
from another account. The outcome arrives via `elitemeetPurchaseVerify`
(completed — verify it) or `elitemeetPurchaseComplete` (cancelled / pending /
error). Product IDs: docs/BILLING.md.

### getProducts({ productIds })

```javascript
const rows = await window.EliteMeetApp.getProducts({ productIds: ["elitemeet_boost_24h"] });
// [{ id, price: "KES 250.00", title, currencyCode }]
```

Localized store prices — show these in the app instead of web prices.

### getPendingPurchases()

Completed store transactions still waiting for server verification. Call on
page load; same shape as the `elitemeetPurchaseVerify` detail.

### finishPurchase({ key, ok })

Call after the server decided. `ok: true` acknowledges/consumes/finishes the
store transaction. `ok: false` (server rejected it): iOS finishes it, Android
leaves it unacknowledged so Google auto-refunds it.

### restorePurchases()

Re-delivers owned purchases through `elitemeetPurchaseVerify` (shown as a
"Restore purchases" button in Settings — required by App Store review).

### openStore()

```javascript
window.EliteMeetApp.openStore();
```

Opens the app's own listing in Google Play / the App Store (e.g. for a "rate
us" flow). Currently a no-op placeholder pending confirmation of whether
EliteMeet wants this — see the TODO in `javascript_bridge.dart`.

## Events (app to website)

### elitemeetTokenUpdate

Fires whenever the FCM token is first available or refreshes — don't rely
solely on calling `getDeviceToken()` once.

```javascript
window.addEventListener('elitemeetTokenUpdate', (e) => {
  const token = e.detail.token; // string | null
  // send to your backend
});
```

### elitemeetPurchaseVerify

A store transaction completed and needs server verification.

```javascript
window.addEventListener('elitemeetPurchaseVerify', (e) => {
  const { key, platform, productId, purchaseToken, transactionId, restored } = e.detail;
  // → verifyStorePurchase on the server → finishPurchase({ key, ok })
});
```

### elitemeetPurchaseComplete

Store-sheet outcomes that don't need verification.

```javascript
window.addEventListener('elitemeetPurchaseComplete', (e) => {
  const { productId, status, errorMessage } = e.detail;
  // status: "cancelled" | "pending" | "error"
});
```

## What the website needs to implement

See `docs/WEBSITE_INTEGRATION.md` for concrete examples covering login/logout
token registration, purchase button wiring, and platform-conditional UI.

## Versioning

The bridge object carries `window.EliteMeetApp.__version` (currently `1`). If a
future native update changes the contract in a breaking way, this number
increments — website code can branch on it if needed. Additive changes (new
methods) don't require a version bump.

## Debugging the bridge during development

Chrome remote debugging (`chrome://inspect`) and Safari's Develop menu are
enabled automatically in non-production builds (see `webview_service.dart`) and
disabled in release — use them to call `window.EliteMeetApp` methods directly
from the browser console while testing against a debug/staging build.
