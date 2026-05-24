import CoreGraphics
import Foundation

protocol ActionDispatching: AnyObject {
    func dispatch(_ action: GestureAction)
}

final class ActionDispatcher: ActionDispatching {
    private let shortcutDispatcher: ShortcutDispatcher
    private let vivaldiTabDispatcher: VivaldiTabDispatcher

    init(
        shortcutDispatcher: ShortcutDispatcher = ShortcutDispatcher(),
        vivaldiTabDispatcher: VivaldiTabDispatcher = VivaldiTabDispatcher()
    ) {
        self.shortcutDispatcher = shortcutDispatcher
        self.vivaldiTabDispatcher = vivaldiTabDispatcher
    }

    func dispatch(_ action: GestureAction) {
        switch action {
        case .shortcut(let shortcut):
            shortcutDispatcher.dispatch(shortcut)
        case .vivaldiTab(let action):
            vivaldiTabDispatcher.dispatch(action)
        case .none:
            break
        }
    }
}

final class ShortcutDispatcher {
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

        down.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)
        up.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)

        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

final class VivaldiTabDispatcher {
    func dispatch(_ action: VivaldiTabAction) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = Self.script(for: action)
            NSAppleScript(source: script)?.executeAndReturnError(&error)

            if let error {
                NSLog("Gestur failed to run Vivaldi tab action: \(error)")
            }
        }
    }

    private static func script(for action: VivaldiTabAction) -> String {
        let offset: String

        switch action {
        case .previousByOrder:
            offset = "-1"
        case .nextByOrder:
            offset = "1"
        }

        return """
        tell application id "com.vivaldi.Vivaldi"
            if not (exists front window) then return

            tell front window
                set tabCount to count of tabs
                if tabCount is 0 then return

                set currentIndex to active tab index
                set nextIndex to currentIndex + (\(offset))

                if nextIndex < 1 then
                    set nextIndex to tabCount
                else if nextIndex > tabCount then
                    set nextIndex to 1
                end if

                set active tab index to nextIndex
            end tell
        end tell
        """
    }
}

enum KeyCodeMapper {
    static func keyCode(for token: KeyCodeToken) -> CGKeyCode? {
        switch token {
        case .one:
            return 18
        case .two:
            return 19
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
        case .leftBracket:
            return 33
        case .rightBracket:
            return 30
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
