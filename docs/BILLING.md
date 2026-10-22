# Billing

Everything below is wired in code. What's left is creating the products in
both stores and adding the server credentials.

Product IDs must match **exactly** (lowercase, underscores) across Play
Console, App Store Connect, `lib/models/purchase_product.dart` and the
website's `src/lib/store-products.ts`. A typo fails silently as "product not
found".

## Product catalog

Prices match the current web prices; set them per country in each console.

### Subscriptions (auto-renewing)

| Product ID                  | Name             | Period  | Price  | Grants                  |
|-----------------------------|------------------|---------|--------|-------------------------|
| `elitemeet_plus_monthly`    | EliteMeet Plus   | 1 month | $19.99 | plan code `plus`        |
| `elitemeet_gold_monthly`    | EliteMeet Gold   | 1 month | $29.99 | plan code `gold`        |
| `elitemeet_premium_monthly` | EliteMeet Premium| 1 month | —      | plan code `premium` (only if you create it) |
| `elitemeet_pro_monthly`     | EliteMeet Pro    | 1 month | —      | plan code `pro` (only if you create it)     |

Plans map by their **code** in Admin → Plans: `elitemeet_<code>_monthly`
(interval month), `elitemeet_<code>_yearly` (interval year),
`elitemeet_<code>_pass` (interval once — create as a consumable). Adding a
new plan on the website only needs a store product with that ID.

### Consumables (one-time, buy again any time)

| Product ID                      | Name                   | Price  | Grants                          |
|---------------------------------|------------------------|--------|---------------------------------|
| `elitemeet_superlike_1`         | 1 Super Like           | $0.99  | 1 super like (30-day expiry)    |
| `elitemeet_superlike_5`         | 5 Super Likes          | $2.99  | 5 super likes (30-day expiry)   |
| `elitemeet_rewind_1`            | 1 Rewind               | $0.99  | 1 rewind (30-day expiry)        |
| `elitemeet_rewind_5`            | 5 Rewinds              | $2.99  | 5 rewinds (30-day expiry)       |
| `elitemeet_boost_24h`           | Boost — 24 hours       | $1.99  | 24h boost                       |
| `elitemeet_boost_7d`            | Boost — 7 days         | $6.99  | 7-day boost                     |
| `elitemeet_boost_30d`           | Boost — 30 days        | $14.99 | 30-day boost                    |
| `elitemeet_message_pack`        | Message bundle         | $0.99  | +N messages (Admin setting, now 10) |
| `elitemeet_chat_unlimited_24h`  | Unlimited chat — 24h   | $2.99  | unlimited messaging 24h         |
| `elitemeet_chat_unlimited_7d`   | Unlimited chat — 7 days| $4.99  | unlimited messaging 7 days      |
| `elitemeet_chat_unlimited_30d`  | Unlimited chat — 30 days| $9.99 | unlimited messaging 30 days     |
| `elitemeet_verification_fee`    | Verification fee       | $0.99  | unlocks ID verification         |

## How a purchase flows

```
Web page (in app)  buyInApp(productId)
   → window.EliteMeetApp.purchase({productId, accountId})
   → Google Play Billing / StoreKit sheet
   → PurchaseService queues the receipt, emits 'elitemeetPurchaseVerify'
   → web page → verifyStorePurchase (server)
        → Google Play Developer API / App Store Server API re-checks it
        → dedupe by transaction id → grant (same code path as Stripe)
   → window.EliteMeetApp.finishPurchase({key, ok})
        → Android: consume (consumables) / acknowledge (subscriptions)
        → iOS: finishTransaction
```

- Nothing is granted client-side. If verification fails, the store
  transaction stays open: StoreKit re-delivers it, and Google auto-refunds
  unacknowledged purchases after 3 days.
- On launch, Android re-checks for paid-but-unfinished purchases. iOS
  re-delivers them automatically.
- Renewals, cancellations, refunds and grace periods come from server
  notifications (section 5), not from the app.
- Android plan switch (Plus → Gold) replaces the old Play subscription with
  proration. iOS does this automatically inside the subscription group.

## 1. Google Play Console — subscriptions

1. Monetize with Play → Products → Subscriptions → Create subscription.
2. Product ID `elitemeet_plus_monthly`, name "EliteMeet Plus".
3. Add **one** base plan: ID `monthly`, Auto-renewing, billing period 1 month,
   set price. **Activate** it (drafts can't be bought).
4. Repeat for `elitemeet_gold_monthly` (and premium/pro if you add those plans).

Keep one base plan per subscription. If you add a free-trial offer later, the
app still buys the base plan until `_loadProducts` in `purchase_service.dart`
is changed to prefer offers.

## 2. Google Play Console — one-time products

1. Monetize with Play → Products → In-app products → Create product.
2. Product ID `elitemeet_superlike_1` and the others from the consumables
   table. Set price and **Activate**.
3. "Consumable" isn't a console setting on Play — the app consumes these
   itself after the server grants them.

## 3. Google Play — server credentials

1. Google Cloud console (same project linked to Play Console) → IAM → Service
   accounts → Create → Keys → Add key → JSON. Enable the **Google Play Android
   Developer API** for that project.
2. Play Console → Users and permissions → Invite new user → the service
   account email → App permissions: EliteMeet → grant **View financial data**
   and **Manage orders and subscriptions**.
3. Website **Admin → Gateways → Google Play Billing**: load the JSON key file,
   check the package name (`net.elitemeet.app`), and Save. The page generates
   the RTDN token and shows the full push endpoint with a Copy button.
4. Real-time developer notifications: Play Console → Monetize with Play →
   Monetization setup → create a Pub/Sub topic, then in Google Cloud Pub/Sub
   add a **push** subscription to the endpoint shown on the Gateways page
   (`https://elitemeet.net/api/public/hooks/play-rtdn?token=…`).
   Grant `google-play-developer-notifications@system.gserviceaccount.com`
   Publisher on the topic. Use "Send test notification" to check it; the
   Gateways page then shows "Last notification: … test".
5. Click **Test connection** on the Gateways page: it signs in as the service
   account and lists every expected product as Active / not active / not found.

Permissions for a new service account can take up to 24h to start working
(API returns 401/403 until then).

## 4. App Store Connect — products

1. Monetization → Subscriptions → create group **"EliteMeet Membership"**.
   Add `elitemeet_plus_monthly` and `elitemeet_gold_monthly` (1 month) to that
   group. Rank Gold above Plus (upgrade = immediate, downgrade = next renewal).
2. Monetization → In-App Purchases → Create → type **Consumable** for every
   ID in the consumables table.
3. For each product: price, localized display name + description, review
   screenshot of the purchase screen.
4. Agreements, Tax, and Banking → Paid Apps agreement must be active.

## 5. App Store — server credentials

1. Users and Access → Integrations → **In-App Purchase** → generate key.
   Download the `.p8` (one-time download), note the Key ID and Issuer ID.
2. Website **Admin → Gateways → Apple App Store**: enter the Issuer ID and
   Key ID, load the `.p8` file, check the bundle ID, and Save.
3. App → App Information → App Store Server Notifications → **Version 2**,
   Production and Sandbox URL:
   `https://elitemeet.net/api/public/hooks/app-store-notifications`
4. Click **Test connection** on the Gateways page: Apple sends a test
   notification to that URL and the page reports whether it arrived.

Server verification tries production first and falls back to sandbox, so
TestFlight and sandbox testers work against the live server.

## 6. Testers

- **Play:** Setup → License testing → add tester Gmail addresses. Upload the
  build to an internal testing track — Play Billing only works for builds
  installed from Play. Accounts not on the list are charged real money.
- **Apple:** Users and Access → Sandbox → add a tester with an email that is
  not a real Apple ID. On the device: Settings → App Store → Sandbox Account.

## Checklist before testing

- [ ] Web deployed and migration `20260923120000_store_billing.sql` applied
- [ ] All product IDs created and **active** in both stores
- [ ] Google Play and App Store saved in Admin → Gateways, Test connection green
- [ ] RTDN push subscription and App Store notification URL set
- [ ] License testers / sandbox tester set up

## Test cases

1. Buy `elitemeet_boost_24h` → toast "Purchase complete", boost active, buy
   it again (proves consume worked).
2. Subscribe to Plus → plan shows in Settings with "Manage" linking to the
   store. Switch to Gold → only Gold billed.
3. Cancel in the store → Settings still shows active until period end; after
   expiry the plan drops (RTDN / Apple notification).
4. Kill the app during a purchase, reopen → purchase is granted on next load.
5. Delete + reinstall with an active sub → Settings → Restore purchases.
6. Sign into a second EliteMeet account on the same device → restore must NOT
   give it the first account's subscription.

## Restore Purchases

Settings → "Restore purchases" (shown only inside the app) calls
`PurchaseService.restorePurchases()`. Everything restored goes back through
server verification. The server refuses to move a subscription to a different
EliteMeet account.

## Alternative checkout

Not implemented. Inside the app, every digital purchase goes through store
billing; Stripe is used only on the website in a normal browser. See
`docs/STORE_COMPLIANCE.md` before changing that.

## Next step

Continue to `docs/SIGNING.md`.
