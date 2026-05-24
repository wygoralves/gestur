#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:?Usage: package-release.sh <version-tag>}"
VERSION="${TAG#v}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
APP_NAME="Gestur"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION-macOS.dmg"
ZIP_NAME="$APP_NAME-$VERSION-macOS.zip"
DMG_PATH="$DIST_DIR/$DMG_NAME"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
CHECKSUMS_PATH="$DIST_DIR/checksums.txt"

if [[ -z "$VERSION" ]]; then
    echo "error: version cannot be empty" >&2
    exit 1
fi

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/sync-version.sh" "$VERSION" "$BUILD_NUMBER"
"$ROOT_DIR/Scripts/build-app.sh"

rm -f "$DIST_DIR"/"$APP_NAME"-*-macOS.dmg
rm -f "$DIST_DIR"/"$APP_NAME"-*-macOS.zip
rm -f "$CHECKSUMS_PATH"

"$ROOT_DIR/Scripts/create-dmg.sh" "$APP_DIR" "$DMG_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > "$(basename "$CHECKSUMS_PATH")"
)

echo "Packaged release assets:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $CHECKSUMS_PATH"
