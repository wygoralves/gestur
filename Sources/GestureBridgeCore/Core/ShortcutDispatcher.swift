import CoreGraphics

protocol ActionDispatching: AnyObject {
    func dispatch(_ action: GestureAction)
}

final class ActionDispatcher: ActionDispatching {
    private let shortcutDispatcher: ShortcutDispatcher

    init(shortcutDispatcher: ShortcutDispatcher = ShortcutDispatcher()) {
        self.shortcutDispatcher = shortcutDispatcher
    }

    func dispatch(_ action: GestureAction) {
        switch action {
        case .shortcut(let shortcut):
            shortcutDispatcher.dispatch(shortcut)
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
