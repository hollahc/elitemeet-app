# Store Compliance

This doc flags what's likely to block or delay submission based on what this
app actually does. It is not legal advice — Apple's and Google's policies
change, and final judgment calls (especially around alternative billing) need
checking against the current rules at submission time, not just this doc.

## Google Play billing considerations

- Digital goods sold for use within the app (the 4 products in
  `docs/BILLING.md`) must go through Google Play Billing — this app already
  does that.
- The Data Safety form (see `docs/PRIVACY_DECLARATIONS.md`) must match actual
  behavior exactly — a mismatch is a common rejection/removal reason, not just
  a formality.

## Apple In-App Purchase considerations

- Same principle — digital goods/subscriptions must go through StoreKit; this
  app already does that.
- Restore Purchases must be a visible, reachable action — see "Restore
  Purchases" below.
- The subscription purchase screen needs a review screenshot on first
  submission (docs/BILLING.md).

## Digital goods / subscriptions

Both platforms require subscriptions to clearly disclose price, billing
period, and auto-renewal terms to the user before purchase — this is
typically handled by the store's own native purchase sheet (which both
platforms show automatically during checkout), not something this app needs
to build separately.

## Alternative payment considerations

**Not implemented in this project.** If you want to explore alternative
billing (e.g. External Offers, or reader-app style external purchase links),
that requires separate program enrollment and eligibility checks with both
Apple and Google that vary by app category and storefront/region — do not
assume it's available; check current eligibility before building anything
toward it. Nothing in this app is built to route around standard store
billing.

## External links

Links to elitemeet.net pages that are ordinary web content (not
purchase-related) are fine to keep in the WebView per normal store policy —
the concern is specifically routing digital-goods purchases outside store
billing without an approved program.

## Privacy permissions

Camera, photo library, and location permission strings in Info.plist and
AndroidManifest.xml must be specific to what the feature does — generic
copy ("this app needs access to X") is a common review flag. Already written
specifically in this project — see `docs/SETUP.md` if you need to revise the
copy.

## Push notification permissions

Requested contextually (not on cold start) — see `docs/PUSH_NOTIFICATIONS.md`.

## Account deletion considerations

Per confirmed project facts: the website already has a delete-account page.
Google Play requires either an in-app account deletion path or a clearly
linked, discoverable web page for it. The simplest compliant approach: a
WebView link to that existing page, reachable without contacting support —
doesn't need a native screen. Confirm this link is actually reachable from
within the app before submitting (e.g. from an account/settings page inside
the WebView itself, since there's no native settings screen in this build).

## Privacy policy / terms of service

Both stores require a privacy policy URL in the store listing. Use
elitemeet.net's existing privacy policy page if one exists; if not, that's a
prerequisite to create before submission (outside this repo's scope).

## Restore Purchases

Apple explicitly checks for this during review. Requirements (see
`docs/BILLING.md` for the implementation):
- Reachable without contacting support.
- Distinct UX states for success, nothing-to-restore, and failure.
- Tested via the delete/reinstall scenario before every submission.

## App review considerations — pre-submission checklist

- [ ] Restore Purchases reachable and tested via reinstall.
- [ ] Account deletion link reachable.
- [ ] Camera/photo/location permission strings are specific, not generic.
- [ ] Push notifications requested contextually, not on launch.
- [ ] PrivacyInfo.xcprivacy present and accurate (docs/IOS_PRIVACY_MANIFEST.md).
- [ ] Data Safety / App Privacy forms match actual behavior
      (docs/PRIVACY_DECLARATIONS.md).
- [ ] Privacy policy URL set in both store listings.
- [ ] Subscription purchase screenshot included (Apple, if applicable).

## Next step

Continue to `docs/PRIVACY_DECLARATIONS.md`.
