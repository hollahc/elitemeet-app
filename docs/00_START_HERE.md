# Start Here — EliteMeet Mobile App Setup

This is the master checklist. Follow it top to bottom — each step links to a
detailed doc with exact commands. Unfamiliar terms are explained the first time
they appear, and defined in full in `docs/GLOSSARY.md`.

Each step below is marked:
- 🖥️ **Code/terminal** — something you run on your computer, no console needed
- 🌐 **Console** — something you do in a website (Firebase, Play Console, App
  Store Connect, Apple Developer)

---

## Phase 1 — Get the project running locally

- [ ] 🖥️ Install Flutter (see `docs/SETUP.md`)
- [ ] 🖥️ Run `flutter create .` in this project folder — fills in the pieces
      that only Flutter's own tooling can generate (Gradle wrapper,
      `local.properties`, `Runner.xcodeproj`, storyboards, etc.) around the
      files already written here. See `docs/SETUP.md`.
- [ ] 🖥️ Run `flutter pub get`
- [ ] 🖥️ Run `flutter analyze` — fix anything it flags before continuing
- [ ] 🖥️ Run the setup wizard: `bash scripts/setup_wizard.sh` (or
      `scripts/setup_wizard.ps1` on Windows) — walks you through the ~6 values
      that need to be filled in project-wide, using the confirmed EliteMeet
      values as defaults so most prompts are just Enter.

## Phase 2 — Branding

- [ ] 🖥️ Drop the real EliteMeet logo files into `assets/branding/` — see
      `docs/SETUP.md` for exact filenames and sizes required.
- [ ] 🖥️ Run `dart run flutter_launcher_icons` — generates every app-icon size
      for both platforms.
- [ ] 🖥️ Run `dart run flutter_native_splash:create` — generates the splash
      screen for both platforms.

## Phase 3 — Firebase (push notifications)

- [ ] 🌐 Confirm you can see the EXISTING EliteMeet Firebase project in the
      Firebase console (the one the website already uses).
- [ ] 🖥️ Run `flutterfire configure` and select that existing project — see
      `docs/FIREBASE.md`. This generates `google-services.json` and
      `GoogleService-Info.plist` and overwrites `lib/firebase_options.dart`
      with real values.
- [ ] 🌐 iOS only: upload an APNs key to the Firebase project — see
      `docs/PUSH_NOTIFICATIONS.md`.

## Phase 4 — Billing (In-App Purchase)

- [ ] 🌐 Create all 4 products in Google Play Console — see `docs/BILLING.md`.
- [ ] 🌐 Create all 4 products in App Store Connect — see `docs/BILLING.md`.
- [ ] 🌐 Add yourself as a Play Console license tester.
- [ ] 🌐 Create an App Store Connect sandbox tester Apple ID.
- [ ] 🖥️ Replace the backend-verification placeholder in
      `lib/services/purchase_service.dart` once the real EliteMeet API
      endpoint exists — see `docs/BILLING.md`, "Before you ship."

## Phase 5 — Deep links

- [ ] 🌐 Host `assetlinks.json` at
      `https://elitemeet.net/.well-known/assetlinks.json` — see
      `docs/DEEP_LINKS.md`.
- [ ] 🌐 Host `apple-app-site-association` at
      `https://elitemeet.net/.well-known/apple-app-site-association`.
- [ ] 🖥️ Enable the Associated Domains capability in Xcode for the iOS target.

## Phase 6 — Signing

- [ ] 🖥️ Android: create the upload keystore and `android/key.properties` —
      see `docs/SIGNING.md`.
- [ ] 🌐 iOS: confirm your Apple Developer account, certificates, and
      provisioning profile are set up — see `docs/SIGNING.md`.

## Phase 7 — Store compliance (do this before submitting, not after)

- [ ] 🌐 Fill in Google Play's Data Safety form — see
      `docs/PRIVACY_DECLARATIONS.md`.
- [ ] 🌐 Fill in Apple's App Privacy ("Nutrition Label") form — same doc.
- [ ] 🖥️ Confirm the account-deletion link is reachable from the app (already
      wired to the website's existing delete-account page) — see
      `docs/STORE_COMPLIANCE.md`.
- [ ] 🖥️ Confirm "Restore Purchases" is reachable and has been tested via the
      reinstall scenario — see `docs/STORE_COMPLIANCE.md`.

## Phase 8 — Testing

- [ ] 🖥️ Follow `docs/TESTING.md` in full. You need at least one physical
      iPhone — push notifications and StoreKit sandbox purchases cannot be
      fully tested on the iOS Simulator.
- [ ] 🖥️ Smoke-test a **release** build specifically (not just debug) — login,
      push, and a sandbox purchase. ProGuard/R8 can break things that a debug
      build won't reveal. See `docs/ANDROID_BUILD.md`.

## Phase 9 — Ship it

- [ ] 🖥️ Follow `docs/RELEASE.md` for the exact build commands.
- [ ] 🌐 Upload to Google Play Internal Testing.
- [ ] 🌐 Upload to TestFlight.
- [ ] 🌐 Submit for review on both stores.

---

Stuck at any step? `docs/TROUBLESHOOTING.md` covers the most common failure at
each phase.
