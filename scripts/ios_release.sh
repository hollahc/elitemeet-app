#!/usr/bin/env bash
# Build the iOS app and upload it to App Store Connect (TestFlight) in one go.
#
#   ./scripts/ios_release.sh            # build number from pubspec.yaml
#   ./scripts/ios_release.sh 11         # override the build number
#
# One-time setup (see docs/IOS_BUILD.md and the iOS build-and-upload guide):
#   1. App Store Connect → Users and Access → Integrations → App Store Connect
#      API → Team Keys → "+" (Access: App Manager). Download AuthKey_<KEYID>.p8
#      and note the Key ID and the Issuer ID shown above the key list.
#   2. mkdir -p ~/.appstoreconnect/private_keys
#      mv ~/Downloads/AuthKey_<KEYID>.p8 ~/.appstoreconnect/private_keys/
#   3. Add to ~/.zshrc (then open a new terminal):
#        export ASC_KEY_ID=<KEYID>
#        export ASC_ISSUER_ID=<ISSUER-ID>
#   4. Xcode → Settings → Accounts: signed in with the team that owns
#      net.elitemeet.app (signing stays automatic).
set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID (App Store Connect API key ID) - see the top of this script}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (App Store Connect API issuer ID) - see the top of this script}"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ -f "$KEY_FILE" ] || { echo "Missing $KEY_FILE - see the top of this script"; exit 1; }

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
BUILD_NAME=${VERSION_LINE%%+*}
BUILD_NUMBER=${1:-${VERSION_LINE##*+}}

echo "==> Pulling latest code"
git pull --ff-only

echo "==> Building EliteMeet $BUILD_NAME ($BUILD_NUMBER)"
flutter clean
flutter pub get
(cd ios && pod install)
flutter build ipa --release --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"

IPA=$(ls build/ios/ipa/*.ipa | head -1)
[ -f "$IPA" ] || { echo "No IPA in build/ios/ipa - open build/ios/archive/Runner.xcarchive in Xcode and upload from the Organizer"; exit 1; }

echo "==> Validating $IPA"
xcrun altool --validate-app --type ios -f "$IPA" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "==> Uploading to App Store Connect"
xcrun altool --upload-app --type ios -f "$IPA" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "==> Done: build $BUILD_NAME ($BUILD_NUMBER) uploaded. It shows in TestFlight after 5-30 min of processing."
