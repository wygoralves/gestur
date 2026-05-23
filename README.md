# GestureBridge

GestureBridge is a native macOS menu-bar utility prototype for browser mouse gestures.

It listens for right-button drag gestures with a CoreGraphics event tap, matches the frontmost app against enabled browser profiles, and dispatches browser actions as synthetic keyboard shortcuts.

## Build

```sh
swift build
```

## Run

```sh
swift run GestureBridge
```

The app runs as a menu-bar utility and opens the permissions screen if Accessibility or Input Monitoring is missing.

## Build the app bundle

```sh
Scripts/build-app.sh
open dist/GestureBridge.app
```

Use the bundled app when testing launch-at-login. `swift run GestureBridge` is useful during development, but macOS login-item registration expects a real `.app` bundle.

The app icon is generated from `Assets/AppIcon.svg` during packaging. The menu-bar icon uses `Assets/MenuBarIconTemplate.svg`, which macOS treats as a template image so it adapts to light and dark menu bars.

## Validate

This machine's Command Line Tools install does not include `XCTest`, so the project includes a plain Swift validation runner:

```sh
swift run GestureBridgeValidation
```

It covers gesture token recognition, profile matching, shortcut key mapping, and default-config migration.

## Default gestures

- `D`: close the current tab.
- `U`: open a new tab.
- `R`: move to the tab on the right.
- `L`: move to the tab on the left.
- `DU`: reopen the last closed tab.
- `UD`: reload.

You can edit profile-specific gesture rules in Settings → Gestures.

## Permissions

GestureBridge needs:

- Accessibility, to send browser keyboard shortcuts.
- Input Monitoring, to observe mouse input while browsers are frontmost.

The app will not start the event tap until both are granted.

## Debug overlay

Enable Settings → General → Show gesture overlay to see the recognized token, path, and matched action while dragging.
