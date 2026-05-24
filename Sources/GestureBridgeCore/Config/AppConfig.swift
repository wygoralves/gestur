import CoreGraphics
import Foundation

struct AppConfig: Codable, Equatable {
    var defaultsRevision: Int?
    var enabled: Bool
    var launchAtLogin: Bool
    var browserOnlyMode: Bool
    var trigger: TriggerConfig
    var recognition: RecognitionConfig
    var profiles: [BrowserProfile]
    var blockedBundleIds: [String]
    var showGestureOverlay: Bool

    func isEnabledForBundleId(_ bundleId: String) -> Bool {
        guard enabled, !blockedBundleIds.contains(bundleId) else {
            return false
        }

        return profiles.contains { profile in
            profile.enabled && profile.bundleIds.contains(bundleId)
        }
    }

    func profile(for bundleId: String) -> BrowserProfile? {
        profiles.first { profile in
            profile.enabled && profile.bundleIds.contains(bundleId)
        }
    }
}

struct TriggerConfig: Codable, Equatable {
    var button: MouseButton
    var requiredModifiers: [ModifierKey]
}

enum MouseButton: String, Codable, CaseIterable, Equatable, Identifiable {
    case right
    case middle
    case other
    case altLeftDrag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .right:
            return "Right mouse button"
        case .middle:
            return "Middle mouse button"
        case .other:
            return "Other mouse button"
        case .altLeftDrag:
            return "Alt + left drag"
        }
    }
}

struct RecognitionConfig: Codable, Equatable {
    var minimumMovementPx: CGFloat
    var segmentThresholdPx: CGFloat
    var jitterTolerancePx: CGFloat
    var maxGestureDurationMs: Int
}

struct BrowserProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var bundleIds: [String]
    var enabled: Bool
    var rules: [GestureRule]
}

struct GestureRule: Codable, Equatable, Identifiable {
    var id: UUID
    var gesture: String
    var label: String
    var action: GestureAction
}

enum GestureAction: Codable, Equatable {
    case shortcut(ShortcutAction)
    case vivaldiTab(VivaldiTabAction)
    case none

    private enum CodingKeys: String, CodingKey {
        case shortcut
        case vivaldiTab
        case none
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.shortcut) {
            self = .shortcut(try container.decode(ShortcutAction.self, forKey: .shortcut))
        } else if container.contains(.vivaldiTab) {
            self = .vivaldiTab(try container.decode(VivaldiTabAction.self, forKey: .vivaldiTab))
        } else {
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .shortcut(let shortcut):
            try container.encode(shortcut, forKey: .shortcut)
        case .vivaldiTab(let action):
            try container.encode(action, forKey: .vivaldiTab)
        case .none:
            try container.encode(true, forKey: .none)
        }
    }

    var displayText: String {
        switch self {
        case .shortcut(let shortcut):
            return shortcut.displayText
        case .vivaldiTab(let action):
            return action.displayText
        case .none:
            return "None"
        }
    }
}

enum VivaldiTabAction: String, Codable, Equatable {
    case previousByOrder
    case nextByOrder

    var displayText: String {
        switch self {
        case .previousByOrder:
            return "Vivaldi previous tab by order"
        case .nextByOrder:
            return "Vivaldi next tab by order"
        }
    }
}

struct ShortcutAction: Codable, Equatable {
    var key: KeyCodeToken
    var modifiers: [ModifierKey]

    var displayText: String {
        let symbols = ModifierKey.displayOrder.compactMap { modifier -> String? in
            modifiers.contains(modifier) ? modifier.symbol : nil
        }

        return (symbols + [key.displayName]).joined()
    }
}

enum KeyCodeToken: String, Codable, CaseIterable, Equatable, Identifiable {
    case one
    case two
    case t
    case w
    case r
    case leftArrow
    case rightArrow
    case leftBracket
    case rightBracket
    case tab

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .one:
            return "1"
        case .two:
            return "2"
        case .t:
            return "T"
        case .w:
            return "W"
        case .r:
            return "R"
        case .leftArrow:
            return "Left"
        case .rightArrow:
            return "Right"
        case .leftBracket:
            return "["
        case .rightBracket:
            return "]"
        case .tab:
            return "Tab"
        }
    }
}

enum ModifierKey: String, Codable, CaseIterable, Equatable, Identifiable {
    case command
    case shift
    case option
    case control

    var id: String { rawValue }

    static let displayOrder: [ModifierKey] = [.control, .option, .shift, .command]

    var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .shift:
            return "⇧"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        }
    }
}
