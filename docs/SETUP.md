# Setup

## Before you start

- A computer running Windows, macOS, or Linux (macOS required later for iOS
  builds specifically — everything in this doc works on any OS)
- About 30–45 minutes for the Flutter install + first build
- Terminal usage — see docs/GLOSSARY.md if a term below is unfamiliar

## 1. Install Flutter

Follow the official installer for your OS at flutter.dev/docs/get-started/install
— it walks you through downloading the SDK and adding it to your PATH.

**How to know it worked:** run

```
flutter doctor
```

Expected output: a checklist with `[✓]` next to "Flutter", "Android toolchain",
and (on macOS) "Xcode". `[✗]` entries need fixing before continuing — the tool
tells you exactly what's missing (e.g. "Android licenses not accepted" → run
`flutter doctor --android-licenses`).

**If it didn't work:** the most common issue is PATH not being updated — close
and reopen your terminal, or restart your computer, then re-run `flutter doctor`.

## 2. Get this project running

From the project root:

```
flutter create .
```

**What this does:** fills in the native scaffolding (Gradle wrapper,
`local.properties`, Xcode project files, storyboards) that only Flutter's own
tooling generates, without touching the files already written in this repo
(`lib/`, the hand-written `android/app/build.gradle`, `AndroidManifest.xml`,
`Info.plist`, etc. all stay as-is).

**How to know it worked:** the command exits with no errors and you now see
`android/gradlew`, `android/local.properties`, and `ios/Runner.xcodeproj` in the
project.

```
flutter pub get
```

**What this does:** downloads every package listed in `pubspec.yaml`.

**How to know it worked:** exits with "Got dependencies!" and no red error text.

```
flutter analyze
```

**What this does:** checks the code for errors without building anything —
much faster than a full build for catching typos/type errors early.

**How to know it worked:** "No issues found!" If it lists issues, fix them
before continuing — building will fail on the same problems, just slower.

## 3. Domain / environment configuration

The website URL lives in exactly one place: `lib/config/app_config.dart`
(`eliteMeetBaseUrl`) plus `lib/config/environment.dart` for the dev/staging/
production switch. Nothing else in the codebase should hard-code a URL — if you
ever find one, that's a bug to fix, not a second place to update the domain.

To build against a non-production environment:

```
flutter run --dart-define=ELITEMEET_ENV=staging
```

Defaults to `production` (`https://elitemeet.net`) if you don't pass this flag.

## 4. Branding assets

Drop these files into `assets/branding/` using these exact names — the
placeholders currently there compile but are not real branding:

| File | Purpose | Source size to provide |
|---|---|---|
| `logo.png` | Loading screen | 512×512px, transparent background |
| `logo_dark.png` | Loading screen, dark mode | 512×512px, transparent background |
| `logo_light.png` | Loading screen, light mode | 512×512px, transparent background |
| `icon.png` | App icon (both platforms) | **1024×1024px, PNG, no transparency/alpha channel, no rounded corners** — see the warning below |
| `splash_logo.png` | Splash screen | 512×512px, transparent background |

**Give the AI/tool the master file at 1024×1024px** — everything else is
generated down from that size by the tools in the next step.

**Why `icon.png` has no alpha channel:** Apple auto-rejects App Store Connect
uploads if the 1024×1024 app icon has any transparency. Flatten it onto a solid
background before exporting.

Once the real files are in place:

```
dart run flutter_launcher_icons

```

**How to know it worked:** `flutter_launcher_icons` prints
"✓ Successfully generated launcher icons"; `flutter_native_splash:create` prints
"[✓] Native splash complete."

**If it didn't work:** almost always a missing or wrong-sized `icon.png`/
`splash_logo.png` — the error message names which file and what it expected.

### Notification icon (Android only)

The FCM notification icon (`android/app/src/main/res/drawable/ic_stat_notify.xml`)
is a separate asset from the app icon, with a different rule: it must be a
**flat white silhouette on a transparent background** — Android renders it as a
solid-color status-bar chip regardless of the actual colors in the file, so a
full-color logo shows up as a white blob. If you only have the full-color logo,
the simplest conversion is: open it in any image editor, select the logo shape,
fill with solid white, discard everything else, export as PNG or trace to SVG/
vector. Replace the placeholder `pathData` in `ic_stat_notify.xml` with the real
shape.

## Next step

Continue to `docs/FIREBASE.md`.
