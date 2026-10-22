# Release

## Before you start

- Everything in `docs/00_START_HERE.md` phases 1–8 completed.
- 30–60 minutes for both store submissions together.

## Google Play — Internal Testing

1. Build the release AAB — see `docs/ANDROID_BUILD.md`.
2. Play Console → your app → Testing → Internal testing → Create new release.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Add release notes, save, review, and roll out.
5. Add tester emails (or a Google Group) under the Internal testing track's
   testers tab, and share the opt-in link with them.

**How to know it worked:** the release shows status "Available to testers" in
Play Console, and a tester who opens the opt-in link and installs the app sees
it launch and load elitemeet.net correctly.

## Google Play — Production release

Once Internal Testing has been verified end-to-end (including the manual
smoke test in docs/ANDROID_BUILD.md):

1. Play Console → Production → Create new release.
2. Upload the same (or a newer) app-release.aab.
3. Complete the Data Safety form if not already done — see
   `docs/PRIVACY_DECLARATIONS.md`.
4. Complete the store listing (screenshots, description, content rating
   questionnaire) if not already done.
5. Submit for review.

**How to know it worked:** Play Console shows the release status as "In
review," then eventually "Live" once Google approves it (review time varies,
commonly a few hours to a few days).

## Apple — TestFlight

1. Build and upload via Xcode Organizer — see `docs/IOS_BUILD.md`, "Uploading
   to TestFlight."
2. App Store Connect → TestFlight tab → wait for the build to finish
   processing (Apple runs automated checks — a missing PrivacyInfo.xcprivacy
   declaration, docs/IOS_PRIVACY_MANIFEST.md, is a common cause of automatic
   rejection at this stage).
3. Add internal testers (any team member on your App Store Connect account) —
   no additional review needed for internal testing.
4. For external testers, fill in the "What to Test" notes and submit for
   Apple's brief Beta App Review (faster and lighter than full App Store
   review).

**How to know it worked:** the build shows "Ready to Test" and testers receive
an email invite / can find it in the TestFlight app.

## Apple — App Store submission

1. App Store Connect → your app → App Store tab → select the build from
   TestFlight.
2. Complete App Privacy ("Nutrition Label") — see `docs/PRIVACY_DECLARATIONS.md`.
3. Complete the store listing (screenshots — including the required
   subscription-purchase screenshot if you have subscriptions, docs/BILLING.md
   — description, keywords, support URL, privacy policy URL).
4. Submit for Review.

**How to know it worked:** status moves through "Waiting for Review" ->
"In Review" -> "Ready for Sale" (or "Pending Developer Release" if you chose
manual release).

**If it didn't work:** Apple's rejection messages in Resolution Center are
usually specific — cross-check against `docs/STORE_COMPLIANCE.md` for the most
common causes tied to this project (missing Restore Purchases button, generic
permission strings, missing account deletion path).

## Next step

If anything above didn't go as expected, check `docs/TROUBLESHOOTING.md`.
