#!/usr/bin/env bash
#
# EliteMeet setup wizard (Mac/Linux). Run this from the project root:
#   bash scripts/setup_wizard.sh
#
# What it does: asks a few questions (with sensible defaults you can just
# press Enter to accept), then writes those values into every file that
# needs them, instead of you hand-editing files across the project.
#
# What it does NOT do: create Firebase/Play Console/App Store Connect
# accounts or products for you, or generate signing certificates. Those
# stay manual — see docs/00_START_HERE.md for the full sequence.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== EliteMeet Setup Wizard ==="
echo "Press Enter at any prompt to accept the default shown in [brackets]."
echo

prompt() {
  local var_name="$1" question="$2" default="$3"
  read -r -p "$question [$default]: " input
  eval "$var_name=\"\${input:-$default}\""
}

prompt DOMAIN "Production domain" "elitemeet.net"
prompt BUILD_ENV "Environment to build for (dev/staging/production)" "production"
prompt ANDROID_APP_ID "Android application ID" "net.elitemeet.app"
prompt IOS_BUNDLE_ID "iOS bundle ID" "net.elitemeet.app"
prompt APP_NAME "App display name" "EliteMeet"
prompt GOOGLE_SERVICES_JSON "Path to google-services.json (from your Firebase project)" ""
prompt GOOGLE_SERVICE_INFO_PLIST "Path to GoogleService-Info.plist (from your Firebase project)" ""

echo
echo "--- Applying values ---"

# 1. app_config.dart — base URL / app name (only rewritten if you changed
#    them from the confirmed defaults; otherwise left untouched).
CONFIG_FILE="lib/config/app_config.dart"
if [ -f "$CONFIG_FILE" ]; then
  sed -i.bak "s#https://elitemeet.net#https://${DOMAIN}#g" "$CONFIG_FILE"
  sed -i.bak "s#appName = 'EliteMeet'#appName = '${APP_NAME}'#g" "$CONFIG_FILE"
  sed -i.bak "s#applicationId = 'net.elitemeet.app'#applicationId = '${ANDROID_APP_ID}'#g" "$CONFIG_FILE"
  rm -f "${CONFIG_FILE}.bak"
  echo "Updated $CONFIG_FILE"
else
  echo "$CONFIG_FILE not found - skipped"
fi

# 2. Android applicationId
ANDROID_GRADLE="android/app/build.gradle"
if [ -f "$ANDROID_GRADLE" ]; then
  sed -i.bak "s#applicationId = \"net.elitemeet.app\"#applicationId = \"${ANDROID_APP_ID}\"#g" "$ANDROID_GRADLE"
  sed -i.bak "s#namespace = \"net.elitemeet.app\"#namespace = \"${ANDROID_APP_ID}\"#g" "$ANDROID_GRADLE"
  rm -f "${ANDROID_GRADLE}.bak"
  echo "Updated $ANDROID_GRADLE"
else
  echo "$ANDROID_GRADLE not found - run 'flutter create .' first"
fi

# 3. iOS bundle ID
IOS_PLIST="ios/Runner/Info.plist"
if [ -f "$IOS_PLIST" ]; then
  sed -i.bak "s#<string>net.elitemeet.app</string>#<string>${IOS_BUNDLE_ID}</string>#g" "$IOS_PLIST"
  sed -i.bak "s#<string>EliteMeet</string>#<string>${APP_NAME}</string>#g" "$IOS_PLIST"
  rm -f "${IOS_PLIST}.bak"
  echo "Updated $IOS_PLIST"
else
  echo "$IOS_PLIST not found"
fi

# 4. google-services.json
if [ -n "$GOOGLE_SERVICES_JSON" ]; then
  if [ -f "$GOOGLE_SERVICES_JSON" ]; then
    mkdir -p android/app
    cp "$GOOGLE_SERVICES_JSON" android/app/google-services.json
    echo "Copied google-services.json into android/app/"
  else
    echo "File not found at $GOOGLE_SERVICES_JSON - skipped"
  fi
else
  echo "Skipped google-services.json (no path given) - Firebase/FCM won't work until this exists"
fi

# 5. GoogleService-Info.plist
if [ -n "$GOOGLE_SERVICE_INFO_PLIST" ]; then
  if [ -f "$GOOGLE_SERVICE_INFO_PLIST" ]; then
    mkdir -p ios/Runner
    cp "$GOOGLE_SERVICE_INFO_PLIST" ios/Runner/GoogleService-Info.plist
    echo "Copied GoogleService-Info.plist into ios/Runner/"
  else
    echo "File not found at $GOOGLE_SERVICE_INFO_PLIST - skipped"
  fi
else
  echo "Skipped GoogleService-Info.plist (no path given) - iOS push won't work until this exists"
fi

echo
echo "=== What's still manual (console-only steps) ==="
echo "  1. Run: flutterfire configure   (regenerates lib/firebase_options.dart with real values)"
echo "  2. Create the 4 IAP products in Google Play Console and App Store Connect - docs/BILLING.md"
echo "  3. Create the Android upload keystore and android/key.properties - docs/SIGNING.md"
echo "  4. Host assetlinks.json and apple-app-site-association on ${DOMAIN} - docs/DEEP_LINKS.md"
echo "  5. Drop real branding assets into assets/branding/, then run:"
echo "       dart run flutter_launcher_icons"
echo "       dart run flutter_native_splash:create"
echo
echo "Full sequence: docs/00_START_HERE.md"
echo "Build environment selected: ${BUILD_ENV} (pass via --dart-define=ELITEMEET_ENV=${BUILD_ENV} when running/building)"
