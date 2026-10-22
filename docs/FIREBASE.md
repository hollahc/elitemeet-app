# Firebase Setup

## Before you start

- Access to the Firebase console (console.firebase.google.com) with permission
  to see the existing EliteMeet project — the one elitemeet.net already uses.
- 10–15 minutes.
- **Important:** this step connects the app to an EXISTING Firebase project. Do
  NOT create a new one — a new project would issue push notifications from a
  different sender than the website, and the token bridge (docs/WEBVIEW_BRIDGE.md)
  would register tokens the backend can't match to the right sender.

## 1. Confirm you can see the right project

Go to console.firebase.google.com and confirm the EliteMeet project is listed
and you can open it. Note its exact project name/ID — you'll pick it by name in
the next step, so if there are multiple similarly-named projects in your
account, confirm which one the website's backend actually uses before
proceeding.

## 2. Install the FlutterFire CLI (one-time, if not already installed)

```
dart pub global activate flutterfire_cli
```

**How to know it worked:** no error; running `flutterfire --version` afterward
prints a version number.

**If it didn't work:** "command not found" after this usually means your
system PATH doesn't include Dart's global package bin directory — the install
output tells you which directory to add.

## 3. Run the configuration command

From the project root:

```
flutterfire configure
```

This will:
1. Ask you to log into your Google account (opens a browser).
2. List your Firebase projects — **select the existing EliteMeet project**,
   not "create a new project."
3. Ask which platforms to configure — select both Android and iOS.
4. Ask to confirm the Android package name — should already show
   `net.elitemeet.app`; confirm it matches.
5. Ask to confirm the iOS bundle ID — same, `net.elitemeet.app`.

**What this generates:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- Overwrites `lib/firebase_options.dart` with real values (replacing the
  `REPLACE_ME` placeholders)

**How to know it worked:** the command ends with "Firebase configuration file
lib/firebase_options.dart generated successfully" and both files above exist.

**If it didn't work:**
- "No Firebase projects found" — you're logged into the wrong Google account;
  the account needs to already have access to the EliteMeet project in Firebase
  console (ask whoever owns it to add you as a member first).
- Command hangs at the browser login step — check for a browser window that
  opened behind your terminal; some environments open it minimized.

## 4. iOS push requires one more thing: an APNs key

Firebase can't deliver push to iOS without an APNs key uploaded to the project.
See `docs/PUSH_NOTIFICATIONS.md` for this step — it only needs doing once per
Firebase project (skip it if the website's backend team has already done this
for the existing project).

## Next step

Continue to `docs/PUSH_NOTIFICATIONS.md`.
