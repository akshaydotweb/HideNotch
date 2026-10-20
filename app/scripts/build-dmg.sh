#!/usr/bin/env bash
# Build, sign, notarize, and staple a distributable HideNotch DMG in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${HIDENOTCH_SIGN_IDENTITY:-Developer ID Application}"

# CI authenticates with an App Store Connect API key, local builds with a keychain profile.
if [ -n "${HIDENOTCH_NOTARY_KEY:-}" ]; then
    NOTARY_AUTH=(--key "$HIDENOTCH_NOTARY_KEY" --key-id "$HIDENOTCH_NOTARY_KEY_ID" --issuer "$HIDENOTCH_NOTARY_ISSUER")
else
    NOTARY_AUTH=(--keychain-profile "${HIDENOTCH_NOTARY_PROFILE:-HideNotch}")
fi

scripts/assemble-app.sh "$IDENTITY"

APP=".build/HideNotch.app"

STAGING=".build/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
DMG="dist/HideNotch.dmg"
rm -f "$DMG"
hdiutil create -volname "HideNotch" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"

SUBMIT_JSON=$(xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait --output-format json)
echo "$SUBMIT_JSON"

if command -v /usr/bin/python3 >/dev/null 2>&1; then
    NOTARY_ID=$(echo "$SUBMIT_JSON" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
    NOTARY_STATUS=$(echo "$SUBMIT_JSON" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
else
    NOTARY_ID=$(echo "$SUBMIT_JSON" | plutil -extract id raw -)
    NOTARY_STATUS=$(echo "$SUBMIT_JSON" | plutil -extract status raw -)
fi

echo "Notarization id: $NOTARY_ID"
echo "Notarization status: $NOTARY_STATUS"

if [ "$NOTARY_STATUS" != "Accepted" ]; then
    echo "Notarization failed; fetching log:" >&2
    xcrun notarytool log "$NOTARY_ID" "${NOTARY_AUTH[@]}"
    exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "DMG: $DMG"
shasum -a 256 "$DMG"
