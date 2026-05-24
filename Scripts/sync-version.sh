#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: sync-version.sh <version-or-tag> [build-number]}"
BUILD_NUMBER="${2:-${GITHUB_RUN_NUMBER:-1}}"
PLIST_PATH="${PLIST_PATH:-$ROOT_DIR/Packaging/Info.plist}"

VERSION="${VERSION#v}"

if [[ -z "$VERSION" ]]; then
    echo "error: version cannot be empty" >&2
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9A-Za-z._+-]+$ ]]; then
    echo "error: version contains unsupported characters: $VERSION" >&2
    exit 1
fi

if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "error: build number must be numeric: $BUILD_NUMBER" >&2
    exit 1
fi

current_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH")"
current_build_number="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH")"

replace_plist_string() {
    local key="$1"
    local value="$2"

    KEY="$key" VALUE="$value" perl -0pi -e '
        my $key = quotemeta($ENV{"KEY"});
        my $value = $ENV{"VALUE"};
        s{(<key>$key</key>\s*<string>)[^<]*(</string>)}{$1$value$2}g;
    ' "$PLIST_PATH"
}

if [[ "$current_version" != "$VERSION" ]]; then
    replace_plist_string "CFBundleShortVersionString" "$VERSION"
fi

if [[ "$current_build_number" != "$BUILD_NUMBER" ]]; then
    replace_plist_string "CFBundleVersion" "$BUILD_NUMBER"
fi

synced_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH")"
synced_build_number="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH")"

if [[ "$synced_version" != "$VERSION" ]] || [[ "$synced_build_number" != "$BUILD_NUMBER" ]]; then
    echo "error: failed to sync $PLIST_PATH to version $VERSION ($BUILD_NUMBER)" >&2
    exit 1
fi

echo "Synced $PLIST_PATH to version $VERSION ($BUILD_NUMBER)"
