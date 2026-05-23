The right product is a **small native macOS menu-bar utility** that recognizes mouse gestures globally, then translates them into browser commands like next tab, previous tab, close tab, new tab, reopen closed tab, back, forward, reload, and so on.

The important architecture decision is this: **do not build this as a browser extension**. To feel like Vivaldi’s built-in mouse gestures across Safari, Chrome, Firefox, Brave, Arc, Edge, Vivaldi, and browser UI areas like the tab strip or toolbar, it needs to run at the macOS input-event layer. Vivaldi’s own feature works by holding the right mouse button or Alt, moving in a pattern, then mapping that gesture to browser actions; it also supports configurable gestures and rocker gestures. ([Vivaldi Browser Help](https://help.vivaldi.com/desktop/shortcuts/mouse-gestures/))

The MVP should be:

> **GestureBridge for macOS**: a native Swift menu-bar app that intercepts right-button drag gestures in selected browsers, recognizes gesture shapes, suppresses the normal right-click context menu only when a gesture is performed, and sends the correct keyboard shortcut for the frontmost browser.

------

# 1. Core research conclusion

## Build it native, not as an extension

A browser extension can only reliably work inside web pages. It will not consistently work on browser chrome, tab strips, address bars, settings pages, internal pages, or across all browsers from one codebase. A native macOS utility can listen to mouse events before the browser handles them, then decide whether to swallow the gesture or let the original right-click pass through.

The correct API family is **CoreGraphics / Quartz Event Services**, specifically a `CGEventTap`. Apple describes Quartz Event Services as the lower-level event system used for observing and altering low-level user input events, and `CGEventTap` callbacks can return `NULL` to delete an event from the stream, which is exactly what is needed to suppress the right-click context menu after recognizing a gesture. ([Apple Developer](https://developer.apple.com/documentation/coregraphics/quartz-event-services?language=objc&utm_source=chatgpt.com))

Do **not** use `NSEvent.addGlobalMonitorForEvents` as the main mechanism. Apple’s own Event Handling Guide says global monitors receive copies of events sent to other apps, but they cannot modify or prevent normal event delivery. That means the browser would still receive the right-click and likely show the context menu, which ruins the Vivaldi-like experience. ([Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html))

## Build it as a menu-bar app

Use a menu-bar app, not a normal dock app. Apple exposes `NSStatusBar.statusItem` for creating a status item in the macOS menu bar, which fits this kind of utility. On macOS 13 and later, Apple’s `SMAppService` is the modern path for registering login items, launch agents, and similar startup behavior. ([Apple Developer](https://developer.apple.com/documentation/AppKit/NSStatusItem?utm_source=chatgpt.com))

Recommended stack:

| Area                | Recommendation                                       |
| ------------------- | ---------------------------------------------------- |
| Language            | Swift                                                |
| UI                  | SwiftUI settings window plus AppKit menu-bar wrapper |
| Event capture       | CoreGraphics `CGEventTap`                            |
| Gesture recognition | Custom lightweight recognizer                        |
| Action dispatch     | Synthetic keyboard shortcuts via `CGEvent`           |
| Config storage      | JSON file or `UserDefaults` for MVP                  |
| Distribution        | Developer ID signed and notarized app                |
| App Store           | Not a good initial target                            |

------

# 2. Existing products and prior art

There are already utilities in this space. The point of building your own is not because the problem is impossible elsewhere, but because a focused, browser-first, privacy-friendly utility can be cleaner than a giant input automation suite.

## MacGesture

**MacGesture** is the closest prior art. It is an open-source macOS app for global mouse gestures. Its README describes configurable global mouse gesture recognition, shortcut invocation by gesture, and app filtering by bundle ID. It also uses gesture acronyms like `L`, `R`, `U`, `D`, and includes browser-like examples such as `D` for new tab, `DR` for close, and repeated `U*u` / `U*d` gestures for previous and next tab. ([GitHub](https://github.com/MacGesture/MacGesture))

Important legal note: MacGesture is GPL-3.0 licensed, so **do not copy its source code** into a proprietary app unless the whole project will be GPL-compatible. Use it as prior art and behavior inspiration only. ([GitHub](https://github.com/MacGesture/MacGesture))

## xGestures

**xGestures** is an older macOS utility that provides system-wide and per-application mouse gestures. It can trigger actions like closing and minimizing windows, sending keystrokes, and disabling gestures in specific apps. It is still a strong proof that the concept is viable on macOS, but it is not where I would start for a modern implementation. ([Brian Kendall](https://www.briankendall.net/xGestures/index.htm))

## Mac Mouse Fix

**Mac Mouse Fix** is not the exact same product, but it proves there is real demand for lightweight mouse enhancement utilities on macOS. It supports configurable click and drag actions, scrolling and navigation enhancements, native Apple Silicon, and planned app-specific profiles. ([GitHub](https://github.com/noah-nuebling/mac-mouse-fix))

## Hammerspoon

Hammerspoon can prototype this quickly because `hs.eventtap` can observe and override input events, including mouse events. It is useful for validation, but I would not use it as the final product because it requires users to install and configure a scripting environment. ([Hammerspoon](https://www.hammerspoon.org/docs/hs.eventtap.html?utm_source=chatgpt.com))

------

# 3. Product shape

## Name for the handoff

Use a working name like **GestureBridge**.

## Product goal

Create a native macOS utility that gives Vivaldi-style mouse gestures to any browser.

## Target user

A macOS user who wants to use Safari, Chrome, Firefox, Arc, Brave, Edge, or any Chromium browser without losing Vivaldi’s mouse gestures for tab and navigation control.

## MVP scope

The MVP should support:

| Feature                   | MVP behavior                                                 |
| ------------------------- | ------------------------------------------------------------ |
| Right-button gestures     | Hold right mouse button, drag a pattern, release             |
| Browser-only mode         | Enabled only for known browser bundle IDs by default         |
| Gesture recognition       | Recognize `L`, `R`, `U`, `D`, and combinations like `DR`, `UL`, `UR`, `DU` |
| Browser actions           | New tab, close tab, previous tab, next tab, reopen closed tab, back, forward, reload |
| Context-menu preservation | Normal right-click still opens the context menu when no gesture is performed |
| Menu-bar control          | Enable/disable, open settings, quit                          |
| Permissions onboarding    | Explain and request Accessibility/Input Monitoring permissions |
| Configurable defaults     | Store rules in JSON or `UserDefaults`                        |
| Per-browser profiles      | Safari, Chromium-family, Firefox profiles                    |

## Non-goals for MVP

Do not build these first:

| Non-goal                        | Reason                                                       |
| ------------------------------- | ------------------------------------------------------------ |
| Full BetterTouchTool competitor | Too broad                                                    |
| Browser extension               | Cannot cover browser chrome or all browsers                  |
| AppleScript-first control       | Adds app-specific fragility and Automation permission prompts |
| App Store distribution          | Sandbox and input-control requirements make this a poor first target |
| Full gesture editor canvas      | Nice later, not needed for first working version             |
| Touchpad gesture replacement    | Trackpad right-click drag behavior is inconsistent           |

------

# 4. macOS API decision

## Why `CGEventTap`

Use `CGEventTapCreate` with a non-listen-only tap. The tap needs to intercept these event types:

```swift
.rightMouseDown
.rightMouseDragged
.rightMouseUp
.otherMouseDown
.otherMouseDragged
.otherMouseUp
.scrollWheel // optional, for rocker or wheel gestures later
```

Apple’s event tap system can observe and alter low-level input. The callback can return the event unchanged, return a modified event, or return `NULL` to remove the event from the stream. That is the mechanism that lets the app prevent the browser from seeing the right-click gesture. ([Apple Developer](https://developer.apple.com/documentation/coregraphics/quartz-event-services?language=objc&utm_source=chatgpt.com))

Mouse buttons beyond left and right are exposed through “other mouse” event types, and CoreGraphics exposes the mouse button number through `CGEventField.mouseEventButtonNumber`. That gives a path for future support of middle-button gestures, side-button gestures, or user-selected trigger buttons. ([Apple Developer](https://developer.apple.com/documentation/coregraphics/cgeventfield/mouseeventbuttonnumber?utm_source=chatgpt.com))

## Why not `NSEvent` global monitors

`NSEvent` global monitors are useful for passive observation, but Apple says global monitors cannot modify or prevent delivery of events. They are therefore not enough for this utility. ([Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html))

## Event tap location

Start with:

```swift
CGEventTapLocation.cgSessionEventTap
```

Use:

```swift
CGEventTapPlacement.headInsertEventTap
CGEventTapOptions.defaultTap
```

Reasoning:

| Option               | Recommendation                                               |
| -------------------- | ------------------------------------------------------------ |
| `.cgSessionEventTap` | Good default for current logged-in session                   |
| `.cghidEventTap`     | More aggressive, useful as fallback, but more invasive       |
| `.defaultTap`        | Required because we need to swallow events                   |
| `.listenOnly`        | Not acceptable for MVP because it cannot suppress the right-click |

Event taps can be disabled by timeout or user input, and Apple exposes `CGEventTapEnable` to re-enable a tap. Keep the callback fast, do not do heavy work inside it, and handle `.tapDisabledByTimeout` / `.tapDisabledByUserInput` by re-enabling the tap. ([Apple Developer](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap%3Aenable%3A)?language=objc&utm_source=chatgpt.com))

------

# 5. Permissions model

This app will need user-granted macOS privacy permissions.

## Accessibility

Accessibility permission is needed because the app is effectively controlling the Mac by sending input and automation-like commands. Apple’s support docs describe that macOS prompts users before letting a third-party app access and control the computer through Accessibility, and users must grant that permission in Privacy & Security. ([Suporte Apple](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac))

## Input Monitoring

Input Monitoring may also be required, especially on newer macOS versions, because the app monitors mouse and possibly keyboard input while other apps are active. Apple describes Input Monitoring as the privacy category for apps that monitor keyboard, mouse, or trackpad input even while using other apps. ([Suporte Apple](https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac?utm_source=chatgpt.com))

Apple also documented that on macOS Catalina and later, apps can check listen-event authorization through `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`, and that event-tap creation can fail when permission has not been granted. ([Apple Developer](https://developer.apple.com/videos/play/wwdc2019/701/?utm_source=chatgpt.com))

## Permission UX

The app should have a first-run permissions screen:

1. Explain why the app needs input access.
2. Show status:
   - Accessibility: granted / missing
   - Input Monitoring: granted / missing
3. Provide buttons:
   - Open Accessibility settings
   - Open Input Monitoring settings
   - Recheck permissions
4. Do not start the event tap until required permissions are present.

Practical implementation:

```swift
enum PermissionStatus {
    case granted
    case missing
    case unknown
}

final class PermissionManager {
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func inputMonitoringStatus() -> IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }
}
```

Codex should verify exact Swift imports and availability:

```swift
import ApplicationServices
import IOKit.hid
```

------

# 6. Action dispatch strategy

## Primary action layer: keyboard shortcuts

The app should primarily send synthetic keyboard shortcuts. This is much simpler and more robust than scripting every browser.

For example:

| Action            | Generic shortcut |
| ----------------- | ---------------- |
| New tab           | `⌘T`             |
| Close tab         | `⌘W`             |
| Reopen closed tab | `⇧⌘T`            |
| Reload            | `⌘R`             |
| Back              | `⌘←` or `⌘[`     |
| Forward           | `⌘→` or `⌘]`     |
| Next tab          | Browser-specific |
| Previous tab      | Browser-specific |

Chrome documents common Mac shortcuts such as `⌘T` for new tab, `⇧⌘T` for reopening closed tabs, `⌘OptionRight` for next tab, `⌘OptionLeft` for previous tab, and `⌘[` / `⌘Left` for back. Safari and Firefox also document overlapping tab and navigation shortcuts, but tab-switching shortcuts vary enough that per-browser profiles are safer than assuming one universal mapping. ([Google Ajuda](https://support.google.com/chrome/answer/157179?co=GENIE.Platform%3DDesktop&hl=en&utm_source=chatgpt.com))

## Important keyboard-layout concern

Because you are in Brazil, avoid relying only on bracket shortcuts like `⌘[` and `⌘]` where possible. Punctuation keycodes can be annoying across keyboard layouts. Prefer arrow-based shortcuts for Chromium-family browsers where available:

| Browser family                      | Previous tab                                                 | Next tab |
| ----------------------------------- | ------------------------------------------------------------ | -------- |
| Chromium, Vivaldi, Brave, Edge, Arc | `⌘⌥←`                                                        | `⌘⌥→`    |
| Safari                              | `⌃⇧Tab`                                                      | `⌃Tab`   |
| Firefox                             | Configurable profile, test both `⌃⇧Tab` / `⌃Tab` and `⌘⌥←` / `⌘⌥→` |          |

The app should let users record or edit shortcuts per action.

## Secondary action layer: Apple Events, optional only

Apple Events can control browser tabs more semantically, but they create extra complexity:

- App-specific scripting dictionaries
- Automation permission prompts
- Sandboxing complications
- Different behavior between Safari, Chrome, Firefox, and Chromium forks

Apple’s sandboxing docs say sandboxed apps can receive Apple Events, send events to themselves, and respond to events, but sending Apple Events to other apps requires special scripting target configuration or temporary exceptions. Apple also provides a Hardened Runtime Apple Events entitlement for apps that send Apple Events. ([Apple Developer](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html))

Recommendation: **do not use Apple Events in the MVP**. Add them later only for advanced features, such as selecting exact tabs, closing tabs without changing focus, or manipulating windows.

------

# 7. Gesture model

## Trigger behavior

Default trigger:

```text
Hold right mouse button -> move pointer -> release
```

Alternative triggers for settings:

| Trigger             | Priority                         |
| ------------------- | -------------------------------- |
| Right mouse button  | MVP default                      |
| Side mouse button   | V2                               |
| Middle mouse button | V2                               |
| Alt + left drag     | V2, useful for trackpad fallback |
| Rocker gestures     | V2                               |

Vivaldi supports right-button gestures and also an Alt-based gesture option, so adding Alt + left drag later makes sense for users without a comfortable mouse. ([Vivaldi Browser Help](https://help.vivaldi.com/desktop/shortcuts/mouse-gestures/))

## Gesture recognition

The recognizer should convert pointer movement into a compact token sequence.

Examples:

| Gesture movement     | Token |
| -------------------- | ----- |
| Drag left            | `L`   |
| Drag right           | `R`   |
| Drag up              | `U`   |
| Drag down            | `D`   |
| Drag down then right | `DR`  |
| Drag up then left    | `UL`  |
| Drag down then up    | `DU`  |

Algorithm:

1. On trigger mouse down:
   - Store start point.
   - Store timestamp.
   - Store frontmost app bundle ID.
   - Enter `possibleGesture`.
   - Swallow the mouse down event for now.
2. On drag:
   - Add point to path.
   - Ignore movement below threshold.
   - Convert movement segment to direction:
     - Horizontal if `abs(dx) > abs(dy) * angleBias`
     - Vertical if `abs(dy) > abs(dx) * angleBias`
     - Otherwise classify by dominant axis or ignore as diagonal jitter.
   - Collapse repeated directions.
   - Once total movement exceeds threshold, mark `activeGesture = true`.
   - Swallow drag events.
3. On mouse up:
   - If `activeGesture = true`:
     - Match gesture against profile for current bundle ID.
     - Dispatch action.
     - Swallow mouse up.
   - If `activeGesture = false`:
     - Replay the original right-click down/up so the browser context menu still opens.
     - Mark replayed events as synthetic so the event tap ignores them.

## Suggested thresholds

| Setting              | Suggested default    |
| -------------------- | -------------------- |
| Minimum movement     | 22 px                |
| Segment threshold    | 12 px                |
| Max gesture duration | 1200 ms              |
| Direction collapse   | Enabled              |
| Jitter tolerance     | 6 px                 |
| Gesture timeout      | Cancel after 1500 ms |

These should be user-configurable.

------

# 8. Default browser gestures

Use a browser-first profile. These are the defaults I recommend:

| Gesture | Action            | Rationale                                                 |
| ------- | ----------------- | --------------------------------------------------------- |
| `D`     | New tab           | Matches common Vivaldi behavior                           |
| `DR`    | Close tab         | Easy, fast, avoids accidental close from simple direction |
| `DU`    | Reopen closed tab | Similar to Vivaldi’s “down then up” idea                  |
| `UL`    | Previous tab      | Up means tab/navigation layer, left means previous        |
| `UR`    | Next tab          | Up means tab/navigation layer, right means next           |
| `L`     | Back              | Common gesture convention                                 |
| `R`     | Forward           | Common gesture convention                                 |
| `UD`    | Reload            | Up-down is deliberate, low accidental risk                |

This preserves Vivaldi-like behavior while making tab control first-class. Vivaldi examples include down for new tab, down-right for close, down-up for opening links/background tab behavior, and left/right for history navigation. ([Vivaldi Browser](https://vivaldi.com/blog/browse-fast-with-mouse-gestures/))

## Browser profiles

### Chromium-family profile

Bundle IDs to include by default:

```text
com.vivaldi.Vivaldi
com.google.Chrome
com.google.Chrome.canary
com.brave.Browser
com.microsoft.edgemac
company.thebrowser.Browser
com.operasoftware.Opera
```

Actions:

| Gesture | Action            | Shortcut |
| ------- | ----------------- | -------- |
| `D`     | New tab           | `⌘T`     |
| `DR`    | Close tab         | `⌘W`     |
| `DU`    | Reopen closed tab | `⇧⌘T`    |
| `UL`    | Previous tab      | `⌘⌥←`    |
| `UR`    | Next tab          | `⌘⌥→`    |
| `L`     | Back              | `⌘←`     |
| `R`     | Forward           | `⌘→`     |
| `UD`    | Reload            | `⌘R`     |

### Safari profile

Bundle ID:

```text
com.apple.Safari
```

Actions:

| Gesture | Action            | Shortcut |
| ------- | ----------------- | -------- |
| `D`     | New tab           | `⌘T`     |
| `DR`    | Close tab         | `⌘W`     |
| `DU`    | Reopen closed tab | `⇧⌘T`    |
| `UL`    | Previous tab      | `⌃⇧Tab`  |
| `UR`    | Next tab          | `⌃Tab`   |
| `L`     | Back              | `⌘←`     |
| `R`     | Forward           | `⌘→`     |
| `UD`    | Reload            | `⌘R`     |

### Firefox profile

Bundle ID:

```text
org.mozilla.firefox
```

Actions:

| Gesture | Action            | Shortcut                  |
| ------- | ----------------- | ------------------------- |
| `D`     | New tab           | `⌘T`                      |
| `DR`    | Close tab         | `⌘W`                      |
| `DU`    | Reopen closed tab | `⇧⌘T`                     |
| `UL`    | Previous tab      | User-configurable default |
| `UR`    | Next tab          | User-configurable default |
| `L`     | Back              | `⌘←`                      |
| `R`     | Forward           | `⌘→`                      |
| `UD`    | Reload            | `⌘R`                      |

Firefox should be treated as configurable because tab-switching shortcuts can be affected by Firefox settings and keyboard preferences. Firefox documents `⇧⌘T` for reopening closed tabs, but full tab navigation behavior is safer to validate in the target environment. ([Suporte Mozilla](https://support.mozilla.org/en-US/kb/keyboard-shortcuts-perform-firefox-tasks-quickly?utm_source=chatgpt.com))

------

# 9. Configuration model

Use a simple Codable model.

```swift
struct AppConfig: Codable {
    var enabled: Bool
    var trigger: TriggerConfig
    var recognition: RecognitionConfig
    var profiles: [BrowserProfile]
    var blockedBundleIds: [String]
    var showGestureOverlay: Bool
}

struct TriggerConfig: Codable {
    var button: MouseButton
    var requiredModifiers: [ModifierKey]
}

enum MouseButton: String, Codable {
    case right
    case middle
    case other
}

struct RecognitionConfig: Codable {
    var minimumMovementPx: CGFloat
    var segmentThresholdPx: CGFloat
    var jitterTolerancePx: CGFloat
    var maxGestureDurationMs: Int
}

struct BrowserProfile: Codable, Identifiable {
    var id: UUID
    var name: String
    var bundleIds: [String]
    var enabled: Bool
    var rules: [GestureRule]
}

struct GestureRule: Codable, Identifiable {
    var id: UUID
    var gesture: String
    var label: String
    var action: GestureAction
}

enum GestureAction: Codable {
    case shortcut(ShortcutAction)
    case none
}

struct ShortcutAction: Codable {
    var key: KeyCodeToken
    var modifiers: [ModifierKey]
}
```

Example persisted JSON:

```json
{
  "enabled": true,
  "trigger": {
    "button": "right",
    "requiredModifiers": []
  },
  "recognition": {
    "minimumMovementPx": 22,
    "segmentThresholdPx": 12,
    "jitterTolerancePx": 6,
    "maxGestureDurationMs": 1200
  },
  "showGestureOverlay": false,
  "blockedBundleIds": [
    "com.apple.finder",
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "com.todesktop.230313mzl4w4u92"
  ],
  "profiles": [
    {
      "id": "A0B929C6-97D5-4385-B636-3C9E0291E957",
      "name": "Chromium browsers",
      "enabled": true,
      "bundleIds": [
        "com.vivaldi.Vivaldi",
        "com.google.Chrome",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser"
      ],
      "rules": [
        {
          "id": "FD99C3FE-77BE-4D6C-A49D-67C54B31B5F7",
          "gesture": "D",
          "label": "New tab",
          "action": {
            "shortcut": {
              "key": "t",
              "modifiers": ["command"]
            }
          }
        },
        {
          "id": "D9DAF1E0-7C39-44A4-A9E2-E9D2A6FCF0F6",
          "gesture": "DR",
          "label": "Close tab",
          "action": {
            "shortcut": {
              "key": "w",
              "modifiers": ["command"]
            }
          }
        }
      ]
    }
  ]
}
```

------

# 10. Runtime architecture

Recommended file structure:

```text
GestureBridge/
  GestureBridgeApp.swift
  AppDelegate.swift

  Core/
    EventTapManager.swift
    GestureRecognizer.swift
    GestureSession.swift
    GestureTypes.swift
    FrontmostAppProvider.swift
    ActionDispatcher.swift
    ShortcutDispatcher.swift
    SyntheticEventMarker.swift
    PermissionManager.swift

  Config/
    AppConfig.swift
    ConfigStore.swift
    DefaultProfiles.swift

  UI/
    StatusBarController.swift
    SettingsWindowController.swift
    SettingsView.swift
    PermissionView.swift
    ProfilesView.swift
    GestureRulesView.swift
    OverlayWindow.swift

  Tests/
    GestureRecognizerTests.swift
    ProfileMatchingTests.swift
    ShortcutMappingTests.swift
```

## Main flow

```text
App launch
  -> Load config
  -> Check permissions
  -> Create menu-bar item
  -> If permissions granted and enabled, start EventTapManager

EventTapManager receives mouse event
  -> Ignore synthetic events
  -> Check frontmost app bundle ID
  -> If app is not enabled, pass event through
  -> Feed event into GestureRecognizer
  -> If recognizer says pass, return event
  -> If recognizer says swallow, return nil
  -> If recognizer emits action, dispatch shortcut async and return nil
```

------

# 11. Event tap skeleton

This is the shape Codex should implement. It is illustrative, not copy-paste final production code.

```swift
import AppKit
import ApplicationServices

final class EventTapManager {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let recognizer: GestureRecognizer
    private let frontmostAppProvider: FrontmostAppProvider
    private let actionDispatcher: ActionDispatcher
    private let configStore: ConfigStore
    private let syntheticMarker: Int64 = 0x47455354555245 // "GESTURE"

    init(
        recognizer: GestureRecognizer,
        frontmostAppProvider: FrontmostAppProvider,
        actionDispatcher: ActionDispatcher,
        configStore: ConfigStore
    ) {
        self.recognizer = recognizer
        self.frontmostAppProvider = frontmostAppProvider
        self.actionDispatcher = actionDispatcher
        self.configStore = configStore
    }

    func start() throws {
        guard tap == nil else { return }

        let mask =
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: EventTapManager.eventTapCallback,
            userInfo: refcon
        ) else {
            throw EventTapError.couldNotCreateTap
        }

        tap = createdTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: createdTap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        tap = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>
            .fromOpaque(refcon)
            .takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == manager.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        return manager.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let config = configStore.current

        guard config.enabled else {
            return Unmanaged.passUnretained(event)
        }

        let bundleId = frontmostAppProvider.frontmostBundleId()

        guard let bundleId,
              config.isEnabledForBundleId(bundleId)
        else {
            return Unmanaged.passUnretained(event)
        }

        let decision = recognizer.handle(type: type, event: event, bundleId: bundleId)

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)

        case .swallow:
            return nil

        case .dispatch(let action):
            DispatchQueue.main.async { [actionDispatcher] in
                actionDispatcher.dispatch(action)
            }
            return nil

        case .replayRightClick(let originalDown, let up):
            DispatchQueue.main.async { [weak self] in
                self?.replayRightClick(originalDown: originalDown, up: up)
            }
            return nil
        }
    }

    private func replayRightClick(originalDown: CGEvent, up: CGEvent) {
        originalDown.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)

        originalDown.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

enum EventTapError: Error {
    case couldNotCreateTap
}
```

------

# 12. Gesture recognizer skeleton

```swift
import CoreGraphics

final class GestureRecognizer {
    private var session: GestureSession?

    private let configStore: ConfigStore
    private let profileMatcher: ProfileMatcher

    init(configStore: ConfigStore, profileMatcher: ProfileMatcher) {
        self.configStore = configStore
        self.profileMatcher = profileMatcher
    }

    func handle(type: CGEventType, event: CGEvent, bundleId: String) -> GestureDecision {
        switch type {
        case .rightMouseDown:
            return handleMouseDown(event: event, bundleId: bundleId)

        case .rightMouseDragged:
            return handleMouseDragged(event: event)

        case .rightMouseUp:
            return handleMouseUp(event: event)

        default:
            return .passThrough
        }
    }

    private func handleMouseDown(event: CGEvent, bundleId: String) -> GestureDecision {
        let point = event.location

        session = GestureSession(
            bundleId: bundleId,
            startPoint: point,
            lastPoint: point,
            startedAt: Date(),
            originalDownEvent: event.copy()!,
            points: [point],
            directions: [],
            didExceedThreshold: false
        )

        return .swallow
    }

    private func handleMouseDragged(event: CGEvent) -> GestureDecision {
        guard var current = session else {
            return .passThrough
        }

        let config = configStore.current.recognition
        let point = event.location

        current.points.append(point)

        let dx = point.x - current.lastPoint.x
        let dy = point.y - current.lastPoint.y
        let distance = hypot(dx, dy)

        guard distance >= config.segmentThresholdPx else {
            session = current
            return .swallow
        }

        if let direction = Direction.classify(dx: dx, dy: dy) {
            if current.directions.last != direction {
                current.directions.append(direction)
            }
            current.lastPoint = point
        }

        let totalDistance = hypot(
            point.x - current.startPoint.x,
            point.y - current.startPoint.y
        )

        if totalDistance >= config.minimumMovementPx {
            current.didExceedThreshold = true
        }

        session = current
        return .swallow
    }

    private func handleMouseUp(event: CGEvent) -> GestureDecision {
        guard let current = session else {
            return .passThrough
        }

        defer { session = nil }

        guard current.didExceedThreshold else {
            guard let originalDown = current.originalDownEvent.copy(),
                  let up = event.copy()
            else {
                return .passThrough
            }

            return .replayRightClick(originalDown: originalDown, up: up)
        }

        let token = current.directions.map(\.rawValue).joined()

        guard let rule = profileMatcher.match(
            bundleId: current.bundleId,
            gesture: token
        ) else {
            return .swallow
        }

        return .dispatch(rule.action)
    }
}

struct GestureSession {
    let bundleId: String
    let startPoint: CGPoint
    var lastPoint: CGPoint
    let startedAt: Date
    let originalDownEvent: CGEvent
    var points: [CGPoint]
    var directions: [Direction]
    var didExceedThreshold: Bool
}

enum Direction: String {
    case left = "L"
    case right = "R"
    case up = "U"
    case down = "D"

    static func classify(dx: CGFloat, dy: CGFloat) -> Direction? {
        let absX = abs(dx)
        let absY = abs(dy)

        guard max(absX, absY) > 0 else {
            return nil
        }

        if absX >= absY {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}

enum GestureDecision {
    case passThrough
    case swallow
    case dispatch(GestureAction)
    case replayRightClick(originalDown: CGEvent, up: CGEvent)
}
```

Note: macOS screen coordinates can make `dy < 0` mean upward movement depending on event coordinate space. Codex should verify with a debug overlay or log during implementation.

------

# 13. Shortcut dispatcher skeleton

```swift
import CoreGraphics

final class ShortcutDispatcher {
    private let syntheticMarker: Int64 = 0x47455354555245

    func dispatch(_ shortcut: ShortcutAction) {
        guard let keyCode = KeyCodeMapper.keyCode(for: shortcut.key) else {
            return
        }

        let flags = CGEventFlags.from(shortcut.modifiers)
        let source = CGEventSource(stateID: .hidSystemState)

        guard let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        ),
        let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return
        }

        down.flags = flags
        up.flags = flags

        down.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)

        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

enum KeyCodeToken: String, Codable {
    case t
    case w
    case r
    case leftArrow
    case rightArrow
    case tab
}

enum ModifierKey: String, Codable {
    case command
    case shift
    case option
    case control
}

enum KeyCodeMapper {
    static func keyCode(for token: KeyCodeToken) -> CGKeyCode? {
        switch token {
        case .t:
            return 17
        case .w:
            return 13
        case .r:
            return 15
        case .leftArrow:
            return 123
        case .rightArrow:
            return 124
        case .tab:
            return 48
        }
    }
}

extension CGEventFlags {
    static func from(_ modifiers: [ModifierKey]) -> CGEventFlags {
        var flags: CGEventFlags = []

        for modifier in modifiers {
            switch modifier {
            case .command:
                flags.insert(.maskCommand)
            case .shift:
                flags.insert(.maskShift)
            case .option:
                flags.insert(.maskAlternate)
            case .control:
                flags.insert(.maskControl)
            }
        }

        return flags
    }
}
```

Codex should add tests for every key mapping and verify the mappings on the target macOS version.

------

# 14. Frontmost app detection

```swift
import AppKit

final class FrontmostAppProvider {
    func frontmostBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func frontmostAppName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
```

This is enough for the MVP. The app should only apply gestures when the frontmost bundle ID matches an enabled browser profile.

------

# 15. UI requirements

## Menu-bar menu

Menu items:

```text
GestureBridge: Enabled ✓
Current app: Safari
Current profile: Safari

Open Settings...
Permissions...
Learn Current App...
Disable for Safari
Launch at Login ✓

Quit
```

## Settings tabs

### General

- Enable GestureBridge
- Start at login
- Trigger button:
  - Right mouse button
  - Middle mouse button
  - Other mouse button
  - Alt + left drag
- Minimum movement threshold
- Show gesture overlay
- Browser-only mode

### Profiles

- List browser profiles
- Bundle IDs
- Enable/disable profile
- Add current frontmost app
- Remove app

### Gestures

Table:

| Gesture | Label        | Action   | Shortcut |
| ------- | ------------ | -------- | -------- |
| `D`     | New tab      | Shortcut | `⌘T`     |
| `DR`    | Close tab    | Shortcut | `⌘W`     |
| `DU`    | Reopen tab   | Shortcut | `⇧⌘T`    |
| `UL`    | Previous tab | Shortcut | `⌘⌥←`    |
| `UR`    | Next tab     | Shortcut | `⌘⌥→`    |

### Permissions

- Accessibility status
- Input Monitoring status
- Buttons to open relevant settings
- Recheck button
- Short explanation

------

# 16. Overlay behavior, optional but useful

A small overlay makes the product feel much better:

- Borderless transparent `NSPanel`
- Appears while gesture is active
- Shows:
  - gesture path line
  - recognized token, for example `UR`
  - resolved action, for example “Next tab”
- Disappears after release

V1 can omit this. V1.1 should add it because it makes debugging gesture recognition dramatically easier.

------

# 17. Distribution recommendation

Start with Developer ID distribution, signed and notarized. Apple’s Developer ID docs describe the outside-Mac-App-Store flow: enable hardened runtime, archive the app, upload it for notarization, and verify the signature. Apple also says software distributed with Developer ID must be notarized on modern macOS. ([Apple Ajuda](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html?utm_source=chatgpt.com))

Do not target the Mac App Store first. The app needs input monitoring, event tapping, Accessibility-style control, and possibly future Apple Events. Those are all easier to ship and debug outside the Mac App Store first.

------

# 18. Critical risks and mitigations

## Risk 1: Right-click context menu delay

Because the app must wait to know whether the right-click becomes a gesture, normal right-click context menus will open after mouse-up, not immediately on mouse-down.

Mitigation:

- Use a low threshold, around 22 px.
- Replay right-click quickly when no gesture happens.
- Let users disable the utility per app.
- Offer alternate trigger button later.

## Risk 2: Some apps need right-drag

Figma, design tools, games, terminals, IDEs, and some web apps may use right-drag.

Mitigation:

- Browser-only mode by default.
- Per-app allowlist.
- Per-app blocklist.
- Menu item: “Disable for current app.”

## Risk 3: Event tap disabled by timeout

Event tap callbacks must be fast. Apple can disable event taps after timeout, and the app needs to re-enable them. ([Apple Developer](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout?language=objc&utm_source=chatgpt.com))

Mitigation:

- Do not run heavy work inside callback.
- Dispatch actions asynchronously.
- Re-enable tap on disabled events.
- Add health indicator in menu.

## Risk 4: Permission confusion

Users may not understand why a browser gesture app needs Accessibility or Input Monitoring.

Mitigation:

- Clear onboarding.
- Explain that the app needs to see mouse gestures and send browser shortcuts.
- Show status and direct buttons to settings.

## Risk 5: Browser shortcut differences

Safari, Chrome, and Firefox differ in tab-switching shortcuts.

Mitigation:

- Per-browser profiles.
- User-editable shortcuts.
- Shortcut recorder.
- Avoid bracket shortcuts as defaults where arrow shortcuts work better.

## Risk 6: Trackpad support

Two-finger secondary click may not behave like a physical right-button drag.

Mitigation:

- Explicitly target external mouse first.
- Add Alt + left-drag fallback later.
- Add Magic Mouse testing separately.

## Risk 7: Secure Input and protected contexts

macOS can restrict input monitoring in some contexts.

Mitigation:

- Detect event tap failures.
- Show “event tap unavailable” state.
- Resume when possible.
- Do not promise behavior in login screen, password fields, or protected system prompts.

------

# 19. Test plan

## Unit tests

### GestureRecognizerTests

Cases:

| Test                    | Expected                    |
| ----------------------- | --------------------------- |
| Simple left movement    | `L`                         |
| Simple right movement   | `R`                         |
| Simple up movement      | `U`                         |
| Simple down movement    | `D`                         |
| Down then right         | `DR`                        |
| Up then left            | `UL`                        |
| Jitter below threshold  | no active gesture           |
| Repeated same direction | collapsed to one token      |
| Unknown gesture         | swallow without dispatch    |
| No movement right-click | replay original right-click |

### ProfileMatchingTests

Cases:

| Test              | Expected         |
| ----------------- | ---------------- |
| Chrome bundle ID  | Chromium profile |
| Vivaldi bundle ID | Chromium profile |
| Safari bundle ID  | Safari profile   |
| Firefox bundle ID | Firefox profile  |
| Unknown app       | pass through     |
| Blocked app       | pass through     |
| Disabled profile  | pass through     |

### ShortcutMappingTests

Cases:

| Test                            | Expected                  |
| ------------------------------- | ------------------------- |
| `command + t`                   | correct flags and keycode |
| `command + w`                   | correct flags and keycode |
| `command + option + rightArrow` | correct flags and keycode |
| `control + shift + tab`         | correct flags and keycode |

## Manual tests

| Scenario                                    | Expected                                   |
| ------------------------------------------- | ------------------------------------------ |
| Right-click without movement in Chrome page | Context menu opens                         |
| `D` gesture in Chrome                       | New tab opens                              |
| `DR` gesture in Chrome                      | Current tab closes                         |
| `UR` gesture in Chrome                      | Next tab selected                          |
| `UL` gesture in Chrome                      | Previous tab selected                      |
| `L` gesture in Safari                       | Goes back                                  |
| Disabled app                                | Right-click works normally                 |
| Event tap disabled and re-enabled           | App recovers                               |
| App quit                                    | Mouse behavior fully normal                |
| Permissions revoked                         | App shows missing permission and stops tap |

## Browser matrix

Test at least:

| Browser | Required          |
| ------- | ----------------- |
| Safari  | Yes               |
| Vivaldi | Yes               |
| Chrome  | Yes               |
| Brave   | Yes               |
| Firefox | Yes               |
| Arc     | Yes, if installed |
| Edge    | Nice to have      |

------

# 20. Implementation milestones for Codex

## Milestone 1: Minimal native shell

Deliver:

- Swift app
- Menu-bar item
- Enable/disable toggle
- Settings window placeholder
- Config loading with defaults

Acceptance:

- App launches without dock icon or with optional dock hiding.
- Menu-bar item exists.
- Toggle persists.

## Milestone 2: Permission manager

Deliver:

- Accessibility check
- Input Monitoring check
- Permission screen
- Recheck permissions
- Clear error when event tap cannot start

Acceptance:

- App does not silently fail.
- User can understand missing permission state.

## Milestone 3: Event tap

Deliver:

- `CGEventTap` for right mouse down, drag, up
- Browser allowlist by bundle ID
- Pass-through outside allowlist
- Swallow inside allowlist during gesture candidate

Acceptance:

- No context menu appears during an active gesture.
- Unknown apps are unaffected.

## Milestone 4: Gesture recognizer

Deliver:

- Direction recognition
- Thresholds
- Token generation
- Unit tests

Acceptance:

- `L`, `R`, `U`, `D`, `DR`, `DU`, `UL`, `UR`, `UD` recognized reliably.

## Milestone 5: Shortcut dispatch

Deliver:

- Synthetic keyboard events
- Chromium, Safari, Firefox default profiles
- Synthetic event marker to avoid loops

Acceptance:

- Gestures perform browser actions.
- Synthetic events are ignored by the event tap.

## Milestone 6: Right-click replay

Deliver:

- Preserve normal right-click if no gesture movement happened
- Replay original right mouse down/up
- Avoid infinite loop using marker

Acceptance:

- Right-click context menu still works in enabled browsers when user does not drag.

## Milestone 7: Settings UI

Deliver:

- Profile list
- Gesture rule list
- Enable/disable profiles
- Edit shortcuts
- Add current app to profile
- Restore defaults

Acceptance:

- User can configure all MVP actions without editing JSON manually.

## Milestone 8: Polish

Deliver:

- Optional overlay
- Launch at login
- Better error handling
- Export/import config
- Notarization setup

Acceptance:

- App is usable as a daily driver.

------

# 21. Codex-ready handoff prompt

Copy this into Codex as the implementation brief:

```text
You are implementing a native macOS utility named GestureBridge.

Goal:
Build a Swift macOS menu-bar app that provides Vivaldi-style mouse gestures in any browser. The app should recognize right-button drag gestures globally, but only act when the frontmost application is an enabled browser profile. It should translate recognized gestures into browser keyboard shortcuts such as new tab, close tab, previous tab, next tab, reopen closed tab, back, forward, and reload.

Hard requirements:
1. Use Swift.
2. Use a native macOS app architecture, preferably SwiftUI for settings and AppKit for menu-bar/status item integration.
3. Use CoreGraphics CGEventTap for mouse input interception.
4. Do not use NSEvent global monitors as the primary mechanism because they cannot suppress or modify events delivered to other apps.
5. Use CGEventTapOptions.defaultTap, not listenOnly, because the app must swallow right-click drag events during gestures.
6. Use synthetic keyboard events via CGEvent as the primary action dispatch mechanism.
7. Do not use AppleScript or Apple Events for the MVP.
8. Do not copy code from MacGesture or any GPL project.
9. Default to browser-only mode.
10. Preserve normal right-click behavior when the user right-clicks without crossing the gesture threshold.
11. Mark synthetic events so the event tap ignores its own replayed right-clicks and keyboard events.
12. Keep event tap callbacks fast. Dispatch heavier work to the main queue.
13. Re-enable the event tap when receiving tapDisabledByTimeout or tapDisabledByUserInput.
14. Implement clear permission checks for Accessibility and Input Monitoring.
15. Store profiles and gesture rules in a Codable config model.

Default browser profiles:
- Chromium browsers:
  - com.vivaldi.Vivaldi
  - com.google.Chrome
  - com.google.Chrome.canary
  - com.brave.Browser
  - com.microsoft.edgemac
  - company.thebrowser.Browser
  - com.operasoftware.Opera
- Safari:
  - com.apple.Safari
- Firefox:
  - org.mozilla.firefox

Default gestures:
- D: New tab
- DR: Close tab
- DU: Reopen closed tab
- UL: Previous tab
- UR: Next tab
- L: Back
- R: Forward
- UD: Reload

Default shortcuts:
Chromium:
- New tab: command + T
- Close tab: command + W
- Reopen closed tab: command + shift + T
- Previous tab: command + option + left arrow
- Next tab: command + option + right arrow
- Back: command + left arrow
- Forward: command + right arrow
- Reload: command + R

Safari:
- New tab: command + T
- Close tab: command + W
- Reopen closed tab: command + shift + T
- Previous tab: control + shift + tab
- Next tab: control + tab
- Back: command + left arrow
- Forward: command + right arrow
- Reload: command + R

Firefox:
- New tab: command + T
- Close tab: command + W
- Reopen closed tab: command + shift + T
- Previous tab: configurable default
- Next tab: configurable default
- Back: command + left arrow
- Forward: command + right arrow
- Reload: command + R

Suggested file structure:
GestureBridge/
  GestureBridgeApp.swift
  AppDelegate.swift
  Core/
    EventTapManager.swift
    GestureRecognizer.swift
    GestureSession.swift
    GestureTypes.swift
    FrontmostAppProvider.swift
    ActionDispatcher.swift
    ShortcutDispatcher.swift
    SyntheticEventMarker.swift
    PermissionManager.swift
  Config/
    AppConfig.swift
    ConfigStore.swift
    DefaultProfiles.swift
  UI/
    StatusBarController.swift
    SettingsWindowController.swift
    SettingsView.swift
    PermissionView.swift
    ProfilesView.swift
    GestureRulesView.swift
    OverlayWindow.swift
  Tests/
    GestureRecognizerTests.swift
    ProfileMatchingTests.swift
    ShortcutMappingTests.swift

Gesture recognition:
- On rightMouseDown:
  - Store original event copy, start point, timestamp, bundle ID.
  - Enter possible gesture state.
  - Return nil to swallow event temporarily.
- On rightMouseDragged:
  - Add points.
  - Ignore movement below segment threshold.
  - Convert movement into L/R/U/D direction tokens.
  - Collapse repeated adjacent directions.
  - If total movement exceeds minimum threshold, mark active gesture.
  - Return nil.
- On rightMouseUp:
  - If no active gesture, replay the original right-click down/up and return nil.
  - If active gesture, match the token to the current app profile, dispatch shortcut, and return nil.
  - If active gesture has no rule, swallow and do nothing.

Default recognition settings:
- minimumMovementPx: 22
- segmentThresholdPx: 12
- jitterTolerancePx: 6
- maxGestureDurationMs: 1200

Acceptance tests:
1. App launches as a menu-bar app.
2. Permissions screen correctly shows missing/granted Accessibility and Input Monitoring.
3. Event tap starts only when permissions are available.
4. In Chrome, right-click with no movement opens the context menu.
5. In Chrome, D opens a new tab.
6. In Chrome, DR closes the current tab.
7. In Chrome, UR moves to next tab.
8. In Chrome, UL moves to previous tab.
9. In Safari, L goes back and R goes forward.
10. Outside enabled browsers, all mouse events pass through unchanged.
11. Synthetic replayed right-clicks do not re-enter the gesture recognizer.
12. Synthetic keyboard events do not re-enter the gesture recognizer.
13. Event tap re-enables itself after tapDisabledByTimeout.
14. Unit tests cover L, R, U, D, DR, DU, UL, UR, UD, jitter below threshold, repeated-direction collapse, unknown gesture, and right-click replay.
15. No MacGesture/GPL code is copied.

Implementation guidance:
- Prefer CGEventTapLocation.cgSessionEventTap for the initial implementation.
- Use .headInsertEventTap placement.
- Use .defaultTap options.
- Use NSWorkspace.shared.frontmostApplication?.bundleIdentifier to detect the current app.
- Use a Codable config store for profiles and gestures.
- Use CGEvent keyboard events for shortcuts.
- Use CGEventField.eventSourceUserData or equivalent to mark synthetic events.
- Keep the callback lightweight and avoid blocking operations inside it.
```

------

# 22. My recommended MVP cut

For the first working version, do **only** this:

1. Menu-bar app.
2. Permission screen.
3. Right-button gesture capture.
4. Browser allowlist.
5. Gesture tokens `D`, `DR`, `DU`, `UL`, `UR`, `L`, `R`, `UD`.
6. Synthetic shortcuts.
7. Right-click replay.
8. JSON/UserDefaults config.
9. Basic settings window.

Do not start with rocker gestures, visual overlays, Apple Events, extension integrations, or advanced device support. The hardest and most important part is making **right-click gesture capture + normal right-click replay** feel correct. Once that works, the rest of the product is mostly configuration and polish.