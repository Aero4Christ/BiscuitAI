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

test -f "$APP_DIR/Contents/Resources/BiscuitAI_BiscuitAI.bundle/BiscuitMascot.png"
test -f "$APP_DIR/Contents/Resources/BiscuitAI_BiscuitAI.bundle/BiscuitNewChatCircle.png"
test -f "$APP_DIR/Contents/Resources/BiscuitAI_BiscuitAI.bundle/BiscuitChatBubble.png"

ICONSET_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/biscuitai-icon.XXXXXX")"
ICONSET_DIR="${ICONSET_ROOT}.iconset"
mv "$ICONSET_ROOT" "$ICONSET_DIR"
trap 'rm -rf "$ICONSET_DIR"' EXIT
for iconSize in 16 32 128 256 512; do
  sips -z "$iconSize" "$iconSize" "$ROOT_DIR/Design Assets/AppIcon.png" \
    --out "$ICONSET_DIR/icon_${iconSize}x${iconSize}.png" >/dev/null
  doubleSize=$((iconSize * 2))
  sips -z "$doubleSize" "$doubleSize" "$ROOT_DIR/Design Assets/AppIcon.png" \
    --out "$ICONSET_DIR/icon_${iconSize}x${iconSize}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

# Clear Finder metadata before signing so the local bundle verifies cleanly.
/usr/bin/xattr -rc "$APP_DIR"

# Prefer a stable local/development signing identity when one is installed.
# This prevents macOS Keychain from treating every rebuilt app as a new caller.
SIGNING_IDENTITY="${BISCUIT_SIGNING_IDENTITY:-}"
if [ -z "$SIGNING_IDENTITY" ]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/^[[:space:]]*[0-9]+\)/ { print $2; exit }')"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
  echo "Warning: no stable code-signing identity found; using an ad-hoc signature."
  echo "Install an Apple Development certificate or set BISCUIT_SIGNING_IDENTITY to avoid repeated Keychain prompts."
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built: $APP_DIR"
echo "Version: $BISCUIT_VERSION ($BISCUIT_BUILD_NUMBER)"
echo "Open it with: open \"$APP_DIR\""
