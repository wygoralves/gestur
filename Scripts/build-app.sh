#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="GestureBridge"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$DIST_DIR/GestureBridge.iconset"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product "$APP_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Assets/MenuBarIconTemplate.svg" "$RESOURCES_DIR/MenuBarIconTemplate.svg"
cp "$ROOT_DIR/Assets/AppIcon.svg" "$RESOURCES_DIR/AppIcon.svg"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    cp -R "$bundle" "$RESOURCES_DIR/"
done
shopt -u nullglob

if command -v rsvg-convert >/dev/null 2>&1; then
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    rsvg-convert -w 16 -h 16 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_16x16.png"
    rsvg-convert -w 32 -h 32 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_16x16@2x.png"
    rsvg-convert -w 32 -h 32 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_32x32.png"
    rsvg-convert -w 64 -h 64 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_32x32@2x.png"
    rsvg-convert -w 128 -h 128 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_128x128.png"
    rsvg-convert -w 256 -h 256 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_128x128@2x.png"
    rsvg-convert -w 256 -h 256 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_256x256.png"
    rsvg-convert -w 512 -h 512 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_256x256@2x.png"
    rsvg-convert -w 512 -h 512 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_512x512.png"
    rsvg-convert -w 1024 -h 1024 "$ROOT_DIR/Assets/AppIcon.svg" -o "$ICONSET_DIR/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/GestureBridge.icns"
    rm -rf "$ICONSET_DIR"
else
    echo "warning: rsvg-convert not found; app bundle will include SVG sources but no .icns file" >&2
fi

chmod +x "$MACOS_DIR/$APP_NAME"

echo "Built $APP_DIR"
echo "Open it with: open '$APP_DIR'"
