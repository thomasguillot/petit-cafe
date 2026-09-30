#!/usr/bin/env bash
#
# Build a distributable drag-to-Applications DMG for Petit Café.
#
# Usage:   ./scripts/make-dmg.sh
# Output:  dist/Petit-Cafe-<version>.dmg   (version from App/project.yml MARKETING_VERSION)
# Needs:   xcodegen, create-dmg   (brew install xcodegen create-dmg)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/App"
BUILD_DIR="$APP_DIR/build/release"
DIST_DIR="$ROOT/dist"

command -v xcodegen   >/dev/null || { echo "error: xcodegen not found (brew install xcodegen)"   >&2; exit 1; }
command -v create-dmg >/dev/null || { echo "error: create-dmg not found (brew install create-dmg)" >&2; exit 1; }

VERSION="$(grep -m1 -E '^[[:space:]]*MARKETING_VERSION:' "$APP_DIR/project.yml" | sed -E 's/.*"([^"]+)".*/\1/')"
# The in-app updater only understands X.Y.Z; anything else ships an app that never sees updates.
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: MARKETING_VERSION must be X.Y.Z, got '$VERSION'" >&2; exit 1; }
echo "==> Testing PetitCafeKit"
(cd "$ROOT/PetitCafeKit" && swift test)

echo "==> Building Petit Café $VERSION (Release)"

cd "$APP_DIR"
xcodegen
xcodebuild -project PetitCafe.xcodeproj -scheme PetitCafe \
  -configuration Release -derivedDataPath build/release \
  -destination 'platform=macOS' clean build

APP="$BUILD_DIR/Build/Products/Release/Petit Café.app"
[ -d "$APP" ] || { echo "error: build did not produce $APP" >&2; exit 1; }
codesign --verify --deep --strict "$APP" || { echo "error: $APP has an invalid signature" >&2; exit 1; }
BUILT_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
[ "$BUILT_VERSION" = "$VERSION" ] || { echo "error: built app is $BUILT_VERSION, expected $VERSION" >&2; exit 1; }

mkdir -p "$DIST_DIR"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"

DMG="$DIST_DIR/Petit-Cafe-$VERSION.dmg"
rm -f "$DMG"

echo "==> Packaging $DMG"
create-dmg \
  --volname "Petit Café" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Petit Café.app" 150 190 \
  --hide-extension "Petit Café.app" \
  --app-drop-link 450 190 \
  --no-internet-enable \
  "$DMG" "$STAGE"

echo "==> Done"
ls -lh "$DMG"
shasum -a 256 "$DMG"
