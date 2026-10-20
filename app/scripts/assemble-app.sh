#!/usr/bin/env bash
# Build and sign HideNotch.app at .build/HideNotch.app. Usage: assemble-app.sh <sign-identity>
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
    echo "usage: $0 <sign-identity>" >&2
    exit 2
fi
IDENTITY="$1"

swift build -c release

APP=".build/HideNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HideNotch "$APP/Contents/MacOS/HideNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"
.build/release/IconGen "$ICONSET"
mkdir -p "$APP/Contents/Resources"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

RESOURCE_BUNDLE=".build/release/HideNotch_HideNotchCore.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "error: $RESOURCE_BUNDLE not found (Bundle.module would fatalError at launch without it)" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"

# The binary looks for Sparkle.framework next to itself; the bundle keeps it in Contents/Frameworks.
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/HideNotch"
mkdir -p "$APP/Contents/Frameworks"
ditto .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"

if [ "$IDENTITY" = "-" ]; then
    SIGN=(codesign --force --sign -)
else
    SIGN=(codesign --force --options runtime --timestamp --sign "$IDENTITY")
fi
# Sign inside out: Sparkle's helpers, the framework, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Updater.app"
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

echo "Assembled $APP"
