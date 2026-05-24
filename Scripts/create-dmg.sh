#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: create-dmg.sh <path-to-app> <output-dmg>}"
DMG_PATH="${2:?Usage: create-dmg.sh <path-to-app> <output-dmg>}"
VOLUME_NAME="${VOLUME_NAME:-Gestur}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$(dirname "$DMG_PATH")"
cp -R "$APP_PATH" "$TMP_DIR/Gestur.app"
ln -s /Applications "$TMP_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Created $DMG_PATH"
