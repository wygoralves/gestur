# Gestur

Gestur is a native macOS menu-bar utility prototype for browser mouse gestures.

It listens for right-button drag gestures with a CoreGraphics event tap, matches the frontmost app against enabled browser profiles, and dispatches browser actions as synthetic keyboard shortcuts.

## Build

```sh
swift build
```

## Run

```sh
swift run Gestur
```

The app runs as a menu-bar utility and opens the permissions screen if Accessibility or Input Monitoring is missing.

## Build the app bundle

```sh
Scripts/build-app.sh
open dist/Gestur.app
```

Use the bundled app when testing launch-at-login. `swift run Gestur` is useful during development, but macOS login-item registration expects a real `.app` bundle.

The app icon is generated from `Assets/AppIcon.svg` during packaging. The menu-bar icon uses `Assets/MenuBarIconTemplate.svg`, which macOS treats as a template image so it adapts to light and dark menu bars.

## Sign and notarize

Unsigned local builds remain the default. To sign:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

To submit a signed app for notarization with an existing notarytool keychain profile:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE_PROFILE="gestur-notary" \
Scripts/build-app.sh
```

The script signs with hardened runtime, verifies the signature, creates a zip archive, submits with `xcrun notarytool`, and staples the result when notarization completes.

## Validate

This machine's Command Line Tools install does not include `XCTest`, so the project includes a plain Swift validation runner:

```sh
swift run GesturValidation
```

It covers gesture token recognition, profile matching, shortcut key mapping, default-config migration, and config import/export.

## Default gestures

- `D`: close the current tab.
- `U`: open a new tab.
- `R`: move to the tab on the right.
- `L`: move to the tab on the left.
- `DU`: reopen the last closed tab.
- `UD`: reload.

You can edit profile-specific gesture rules in Settings → Gestures.

Vivaldi has its own default profile because it separates tab cycling from switching tabs by displayed order. Gestur uses Vivaldi's scripting interface for left and right gestures so tab switching stays by displayed order even when a text field has focus.

Use the record button in a gesture row to draw a gesture in the recording pad instead of typing the token manually.

## Permissions

Gestur needs:

- Accessibility, to send browser keyboard shortcuts.
- Input Monitoring, to observe mouse input while browsers are frontmost.
- Automation for Vivaldi, to switch Vivaldi tabs by displayed order without relying on fragile keyboard shortcuts.

The app will not start the event tap until both are granted.

## Debug overlay

Enable Settings → General → Show gesture overlay to see the recognized token, path, and matched action while dragging.

## Diagnostics

Settings → Diagnostics shows the current frontmost app, matched profile, event tap state, permission state, last gesture token, last action, and last event decision. Use it when tuning profiles or confirming that an app is being matched correctly.

## Import/export config

Settings → General → Configuration has import and export actions for the JSON config. This is useful before changing several gesture rules or when moving profiles between Macs.
