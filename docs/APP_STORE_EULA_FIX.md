# Guideline 3.1.2 — Terms of Use (EULA) link in the app metadata

**Apple's message:** the submission offers auto-renewable subscriptions
(EliteMeet Plus, EliteMeet Gold) but the App Store product page has no
functional link to the Terms of Use (EULA).

The app itself already shows the links (subscription screen: Terms of Use
(EULA) → Apple's standard EULA, plus our Terms of Service and Privacy Policy).
What's missing is the **App Store Connect metadata**. Fix it there:

## 1. App Description — add the links (every localization)

App Store Connect → Apps → EliteMeet → the iOS version being submitted →
**Description**. Paste this at the very end, then repeat for **each
language** listed in the localization menu (top right):

```
Subscriptions
EliteMeet Plus and EliteMeet Gold are auto-renewing monthly subscriptions. Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. Manage or cancel any time in your Apple Account settings.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://elitemeet.net/legal/privacy
Terms of Service: https://elitemeet.net/legal/terms
```

Description text can only be changed on a version that is editable
("Prepare for Submission" / "Rejected" / "Developer Rejected"), which this
one is.

## 2. Privacy Policy URL field

App Store Connect → **App Information** (or App Privacy) → **Privacy Policy
URL**: `https://elitemeet.net/legal/privacy` — confirm it's filled in.

## 3. Leave the License Agreement as Apple's standard

App Information → **License Agreement** should say "Apple's Standard License
Agreement". Don't add a custom EULA unless you also change the description
link above to point to it.

## 4. Reply to App Review

App Store Connect → App Review → the submission → **Reply to App Review**:

```
Hello App Review team,

Thank you for the feedback. We've added a functional link to the Terms of Use (EULA) to the App Description in every localization:
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://elitemeet.net/legal/privacy

Inside the app, the subscription screen (Profile → Upgrade) shows each subscription's title, length and price, the auto-renewal terms, and the same Terms of Use (EULA) and Privacy Policy links.

Thank you,
ELITEMEET LLC
```

Then **Resubmit to App Review**. No new build is needed for this issue —
it's metadata only.
