
# Coins and gifts: store setup

Coins buy gifts in lives and rooms. Coin packs are sold through Google Play
Billing and the App Store inside the app, and through Stripe on the website.
This page lists what to create in Play Console and App Store Connect.

The rest of billing (subscriptions, boosts, credentials, notifications) is in
`docs/BILLING.md`. Coins use the same setup and the same server verification.

## What the app needs

Nothing. The website passes the coin product ID to the app, and the app loads
any product it doesn't already know from the store when it's bought
(`purchase_service.dart`). Coin packs are consumables, so the app consumes
them on Android after the server credits the coins, and the same pack can be
bought again. No new app build is needed for coins on Google Play.

## Coin packs

Create all seven as **consumable** one-time products in **both** stores.
IDs must match exactly (lowercase, underscores). They come from the website's
`src/lib/coins.ts` and `src/lib/store-products.ts`.

| Product ID              | Name         | Coins  | Price (USD) | Label      |
|-------------------------|--------------|--------|-------------|------------|
| `elitemeet_coins_70`    | 70 Coins     | 70     | $0.99       |            |
| `elitemeet_coins_350`   | 350 Coins    | 350    | $4.99       |            |
| `elitemeet_coins_700`   | 700 Coins    | 700    | $9.99       | Popular    |
| `elitemeet_coins_1400`  | 1,400 Coins  | 1,400  | $19.99      |            |
| `elitemeet_coins_3500`  | 3,500 Coins  | 3,500  | $49.99      |            |
| `elitemeet_coins_7000`  | 7,000 Coins  | 7,000  | $99.99      | Best value |
| `elitemeet_coins_17500` | 17,500 Coins | 17,500 | $249.99     |            |

The coin amount comes from the product ID on the server, not from the store's
name or price. Changing a price in a console doesn't change how many coins
are credited.

Suggested description (both stores):
"Coins for sending gifts to people in EliteMeet lives and rooms."

## Google Play Console

1. Monetize with Play → Products → **One-time products** → Create one-time
   product.
2. Product ID: `elitemeet_coins_70`. Name: "70 Coins". Description as above.
3. Add a purchase option (buy), set the price to $0.99, and let Play convert
   it for other countries.
4. **Activate** it. Drafts and inactive products can't be bought.
5. Repeat for the other six packs.

"Consumable" isn't a console setting on Play; the app consumes the purchase
itself. Use the **Test connection** button on the website's Admin → Gateways →
Google Play Billing page to check that every coin ID shows as Active.

## App Store Connect

1. Monetization → In-App Purchases → **Create** → type **Consumable**.
2. Reference name: "70 Coins". Product ID: `elitemeet_coins_70`.
3. Availability: all countries where the app is sold.
4. Price: $0.99, with automatic prices for other countries.
5. App Store localization (English at least): display name "70 Coins" and the
   description above.
6. Review information: a screenshot of the coin shop in the app (in a live or
   room, tap the gift button → coin shop), plus a short note: "Coins are
   used to send gifts in lives and rooms."
7. Repeat for the other six packs.
8. **Submit them with an app version.** A new in-app purchase can only be
   approved together with an app version: on the version page, under In-App
   Purchases and Subscriptions, add all seven, then submit the build. Until
   they're approved they work only in Sandbox and TestFlight.

Apple's Paid Apps agreement must be active (Business → Agreements).

## App Review notes (both stores)

Reviewers will ask how to reach the coin shop and what coins are for. Add to
`docs/APP_REVIEW_NOTES.md` and the review notes in each console:

- Where: open a live or a room → gift button → coin shop.
- What: coins buy gifts (rose 1 coin up to dream date 9,999 coins) sent to the
  host or anyone on camera.
- Coins don't expire and can't be turned back into money by the buyer.
- People who receive gifts earn a share of the gift's value, paid out monthly
  by EliteMeet (PayPal, bank or M-Pesa). Buying coins and sending gifts always
  goes through in-app purchase in the app.

## Before testing

- [ ] Website with the coins commit (`8cde386`) deployed to elitemeet.net
- [ ] Migration `20261110120000_coins_gifts_payouts.sql` applied
- [ ] All seven coin products created and **active** (Play) / ready to submit
      (App Store)
- [ ] Admin → Gateways → Test connection lists the coin IDs as found
- [ ] License testers (Play) and a sandbox tester (Apple) set up, as in
      `docs/BILLING.md` section 6

## Test cases

1. In a live, open the coin shop. Prices show in the local currency from the
   store, not the website's USD prices.
2. Buy `elitemeet_coins_70` → balance goes up by 70. Buy it again (proves the
   purchase was consumed / finished).
3. Send a rose → balance goes down by 1; the receiver's Earnings page shows it.
4. Kill the app during a coin purchase and reopen → coins are credited once,
   not twice.
5. Buy coins on the website with a card → the same balance shows in the app.
