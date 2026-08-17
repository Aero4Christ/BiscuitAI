#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION_FILE="$ROOT_DIR/Config/build-version.env"
if [ -f "$VERSION_FILE" ]; then
  # This file is source-controlled project configuration, not user input.
  source "$VERSION_FILE"
fi

BISCUIT_VERSION="${BISCUIT_VERSION:-1.0.0}"
BISCUIT_BUILD_NUMBER="${BISCUIT_BUILD_NUMBER:-1}"

swift build -c release

APP_DIR="$ROOT_DIR/Build/BiscuitAI.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/release/BiscuitAI" "$APP_DIR/Contents/MacOS/BiscuitAI"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BISCUIT_VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BISCUIT_BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE="$ROOT_DIR/.build/release/BiscuitAI_BiscuitAI.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

# Clear Finder metadata before signing so the local bundle verifies cleanly.
xattr -cr "$APP_DIR"

# An ad-hoc signature allows this locally built app to launch on this Mac.
codesign --force --deep --sign - "$APP_DIR"

echo "Built: $APP_DIR"
echo "Version: $BISCUIT_VERSION ($BISCUIT_BUILD_NUMBER)"
echo "Open it with: open \"$APP_DIR\""
